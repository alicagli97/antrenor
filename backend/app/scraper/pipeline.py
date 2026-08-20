# -*- coding: utf-8 -*-
"""Tarama hattı: kaynaklardan duyurulari cek, normalize et, tekrarlari ayikla, kaydet."""
from __future__ import annotations

import asyncio
import hashlib
import json
import pathlib
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, Iterable, List, Optional

from bs4 import BeautifulSoup
from sqlalchemy import select

from ..config import (DATA_DIR, FETCH_DETAIL_PAGES, MAX_ITEMS_PER_SOURCE,
                      SCRAPE_CONCURRENCY)
from ..models import Announcement, Federation, ScrapeRun
from . import extract
from .adapters import ADAPTERS
from .http_client import get, make_client
from .registry import BY_SLUG

SOURCES_FILE = DATA_DIR / "sources.json"


@dataclass
class FetchResult:
    slug: str
    source_url: str
    items: List[extract.Item]
    ok: bool
    error: str = ""


def load_sources() -> Dict[str, List[dict]]:
    if not SOURCES_FILE.exists():
        return {}
    return json.loads(SOURCES_FILE.read_text(encoding="utf-8"))


def sane_date(value: Optional[datetime]) -> Optional[datetime]:
    """Gelecek tarihli veya cok eski degerleri eler.

    Liste kartlarindaki tarih bazen duyurunun degil, ETKINLIGIN tarihi oluyor
    (ör. "15-17 Mayıs 2027 Aday Hakem Kursu"). Bu tarihler akisi bozmasin diye
    yayin tarihi olarak kabul edilmez; kayit "ilk gorulme" zamaniyla siralanir.
    """
    if value is None:
        return None
    now = datetime.now(timezone.utc)
    if value > now + timedelta(hours=2):
        return None
    if value < now - timedelta(days=365 * 12):
        return None
    return value


def fingerprint(slug: str, item: extract.Item) -> str:
    """URL bazli kimlik. Baslik sonradan duzeltilse bile kayit tekrarlanmaz."""
    url = re.sub(r"[?&](utm_[^=]+|fbclid|gclid)=[^&]*", "", item.url).rstrip("/")
    return hashlib.sha1(f"{slug}|{url}".encode("utf-8")).hexdigest()


async def fetch_source(client, slug: str, source: dict) -> FetchResult:
    url, kind = source["url"], source["kind"]
    try:
        if kind == "wp_json":
            r = await get(client, url, expect_json=True)
            items = extract.from_wp_json(r.json(), url) if r else []
        elif kind == "rss":
            r = await get(client, url)
            items = extract.from_rss(r.text, url) if r else []
        elif kind == "render":
            from .adapters import render_html
            html = await render_html(url)
            if not html:
                return FetchResult(slug, url, [], False, "render bos dondu")
            return FetchResult(slug, url, extract.from_html_list(html, url)[:MAX_ITEMS_PER_SOURCE], True)
        else:
            r = await get(client, url)
            items = extract.from_html_list(r.text, str(r.url)) if r else []
        if not r:
            return FetchResult(slug, url, [], False, "kaynak yanit vermedi")
        return FetchResult(slug, url, items[:MAX_ITEMS_PER_SOURCE], True)
    except Exception as exc:
        return FetchResult(slug, url, [], False, f"{type(exc).__name__}: {exc}")


async def fetch_detail(client, item: extract.Item) -> str:
    """Detay sayfasindan gercek baslik ve ana metni cikarir."""
    r = await get(client, item.url)
    if not r or "html" not in r.headers.get("content-type", "text/html"):
        return ""
    # Detay sayfasindaki og:title/h1 en guvenilir baslik kaynagidir:
    # bircok liste sayfasi baglanti metnine spot yaziyi koyuyor.
    better = extract.best_detail_title(r.text)
    if better and len(better) >= 15 and not extract.is_generic_title(better):
        item.title = better
    soup = BeautifulSoup(r.text, "lxml")
    for bad in soup.find_all(["script", "style", "nav", "header", "footer", "aside", "form"]):
        bad.decompose()
    candidates = soup.select("article, .content, .icerik, .detay, .news-detail, .post-content, main")
    node = max(candidates, key=lambda n: len(n.get_text(" ", strip=True)), default=None) or soup.body
    if node is None:
        return ""
    text = extract.clean(node.get_text(" "))
    if not item.published_at:
        item.published_at = extract.parse_tr_date(text[:800]) if hasattr(extract, "parse_tr_date") else None
    return text[:4000]


async def collect(slugs: Optional[Iterable[str]] = None,
                  known_fingerprints: Optional[set] = None) -> List[FetchResult]:
    sources = load_sources()
    targets = [s for s in (slugs or sources.keys()) if s in BY_SLUG]
    results: List[FetchResult] = []
    sem = asyncio.Semaphore(SCRAPE_CONCURRENCY)

    async with make_client() as client:
        async def run(slug: str):
            async with sem:
                # Ozel adaptor varsa once o denenir (JS ile calisan siteler icin)
                if slug in ADAPTERS:
                    try:
                        items = await ADAPTERS[slug](client)
                        if items:
                            results.append(FetchResult(slug, f"adapter:{slug}", items[:MAX_ITEMS_PER_SOURCE], True))
                            return
                        # Bos donen adaptor sessizce kaybolmasin: kayit birak
                        if not sources.get(slug):
                            results.append(FetchResult(slug, f"adapter:{slug}", [], False,
                                                       "adaptor bos dondu (bot korumasi olabilir)"))
                            return
                    except Exception as exc:
                        results.append(FetchResult(slug, f"adapter:{slug}", [], False,
                                                   f"{type(exc).__name__}: {exc}"))
                for source in sources.get(slug, [])[:2]:
                    res = await fetch_source(client, slug, source)
                    results.append(res)
                    if res.ok and res.items:
                        break

        await asyncio.gather(*[run(s) for s in targets])

        if FETCH_DETAIL_PAGES:
            # Detay sayfasi yalnizca DAHA ONCE GORULMEMIS duyurular icin cekilir
            known = known_fingerprints or set()
            detail_targets = [(r, i) for r in results for i in r.items[:15]
                              if r.ok and fingerprint(r.slug, i) not in known
                              and (len(i.summary) < 120 or len(i.title) > 90)]

            async def detail(res, item):
                async with sem:
                    text = await fetch_detail(client, item)   # baslik ve tarihi de duzeltir
                    if text and len(item.summary) < 120:
                        item.summary = text[:600]

            await asyncio.gather(*[detail(r, i) for r, i in detail_targets[:250]])

    return results


def persist(db, results: List[FetchResult]) -> List[Announcement]:
    """Yeni duyurulari kaydeder ve push icin listeler."""
    fed_rows = {f.slug: f for f in db.execute(select(Federation)).scalars()}
    new_rows: List[Announcement] = []

    for res in results:
        fed = fed_rows.get(res.slug)
        run = ScrapeRun(federation_slug=res.slug, source_url=res.source_url,
                        ok=res.ok, items_found=len(res.items), error=res.error[:500])
        if fed is None:
            run.error = "federasyon kaydi yok"
            db.add(run)
            continue

        fps = [fingerprint(res.slug, item) for item in res.items]
        existing = set(db.execute(
            select(Announcement.fingerprint).where(Announcement.fingerprint.in_(fps))
        ).scalars()) if fps else set()

        added = 0
        for item, fp in zip(res.items, fps):
            if fp in existing:
                continue
            existing.add(fp)
            # Baslik detay sayfasindan duzeltilmis olabilir; siniflandirmayi tazele
            item.category, item.tags = extract.classify(
                item.title, item.summary, trust_summary=item.source_kind != "html")
            row = Announcement(
                federation_id=fed.id,
                fingerprint=fp,
                title=item.title[:400],
                url=item.url[:800],
                summary=item.summary[:2000],
                content=(item.summary or "")[:4000],
                image_url=(item.image or None),
                category=item.category,
                tags=",".join(item.tags),
                published_at=sane_date(item.published_at) or datetime.now(timezone.utc),
                source_kind=item.source_kind,
            )
            db.add(row)
            new_rows.append(row)
            added += 1

        run.items_new = added
        run.finished_at = datetime.now(timezone.utc)
        db.add(run)

    db.commit()
    return new_rows


async def run_once(db, slugs: Optional[Iterable[str]] = None) -> List[Announcement]:
    known = set(db.execute(select(Announcement.fingerprint)).scalars())
    results = await collect(slugs, known)
    return persist(db, results)
