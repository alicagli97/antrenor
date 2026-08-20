# -*- coding: utf-8 -*-
"""Bir federasyon sitesinde duyuru/haber kaynagini otomatik bulur.

Sira: WordPress REST -> RSS/Atom -> duyuru & haber HTML liste sayfalari.
Her aday puanlanir; en iyi 1-3 kaynak kaydedilir. Boylece site tasarimi
degistiginde yeniden kesif calistirmak yeterlidir.
"""
from __future__ import annotations

import asyncio
from dataclasses import asdict, dataclass, field
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from . import extract
from .http_client import get, make_client

COMMON_FEEDS = ["/feed", "/feed/", "/rss", "/rss.xml", "/feed.xml", "/rss/", "/atom.xml",
                "/duyurular/feed", "/haberler/feed", "/category/duyurular/feed"]

COMMON_LIST_PATHS = [
    "/duyurular", "/duyuru", "/duyurular/", "/haberler", "/haber", "/haberler/",
    "/Duyurular", "/Haberler", "/tr/haberler", "/tr/duyurular", "/icerik/duyurular",
    "/tr/duyurular", "/tr/haberler", "/category/duyurular", "/category/duyuru",
    "/category/haberler", "/genel-duyurular", "/duyurular.aspx", "/haberler.aspx",
    "/tum-duyurular", "/tum-haberler", "/duyurular.php", "/haberler.php",
]

LIST_WORDS = ("duyuru", "haber", "announcement", "news", "bulten", "bülten")


@dataclass
class Source:
    url: str
    kind: str                 # wp_json | rss | html
    score: float = 0.0
    item_count: int = 0
    dated_ratio: float = 0.0
    label: str = ""
    sample: List[str] = field(default_factory=list)


def _score(items: List[extract.Item]) -> tuple[float, int, float]:
    if not items:
        return 0.0, 0, 0.0
    uniq = {i.url for i in items}
    dated = sum(1 for i in items if i.published_at)
    ratio = dated / len(items)
    long_titles = sum(1 for i in items if len(i.title) >= 25) / len(items)
    score = min(len(uniq), 40) * 1.0 + ratio * 25 + long_titles * 10
    return score, len(uniq), ratio


async def _try_wp_json(client, root: str) -> Optional[Source]:
    for path in ("/wp-json/wp/v2/posts?per_page=20&_embed", "/?rest_route=/wp/v2/posts&per_page=20"):
        url = urljoin(root, path)
        r = await get(client, url, expect_json=True)
        if not r:
            continue
        try:
            items = extract.from_wp_json(r.json(), root)
        except Exception:
            continue
        if len(items) >= 3:
            s, n, ratio = _score(items)
            return Source(url=url, kind="wp_json", score=s + 15, item_count=n,
                          dated_ratio=ratio, label="WordPress REST",
                          sample=[i.title for i in items[:3]])
    return None


async def _feed_candidates(client, root: str, home_html: str) -> List[str]:
    urls: List[str] = []
    soup = BeautifulSoup(home_html or "", "lxml")
    for link in soup.find_all("link", href=True):
        t = (link.get("type") or "").lower()
        if "rss" in t or "atom" in t:
            urls.append(urljoin(root, link["href"]))
    for a in soup.find_all("a", href=True):
        h = a["href"].lower()
        if h.rstrip("/").endswith(("/feed", "/rss", "rss.xml", "feed.xml")):
            urls.append(urljoin(root, a["href"]))
    urls += [urljoin(root, p) for p in COMMON_FEEDS]
    return list(dict.fromkeys(urls))[:10]


async def _try_rss(client, root: str, home_html: str) -> List[Source]:
    out: List[Source] = []
    for url in await _feed_candidates(client, root, home_html):
        r = await get(client, url)
        if not r:
            continue
        body = r.text.lstrip()
        if not body.startswith("<") or ("<rss" not in body[:600] and "<feed" not in body[:600]
                                        and "<channel" not in body[:900]):
            continue
        items = extract.from_rss(r.text, root)
        if len(items) >= 3:
            s, n, ratio = _score(items)
            out.append(Source(url=url, kind="rss", score=s + 10, item_count=n,
                              dated_ratio=ratio, label="RSS",
                              sample=[i.title for i in items[:3]]))
    return out


def _list_page_candidates(root: str, home_html: str) -> List[tuple[str, str]]:
    """(url, etiket) ciftleri: menudeki duyuru/haber baglantilari + yaygin yollar."""
    found: List[tuple[str, str]] = []
    soup = BeautifulSoup(home_html or "", "lxml")
    base_host = urlparse(root).netloc.replace("www.", "")
    for a in soup.find_all("a", href=True):
        text = extract.clean(a.get_text(" "))
        href = a["href"]
        blob = f"{text} {href}".lower()
        if not any(w in blob for w in LIST_WORDS):
            continue
        full = urljoin(root, href)
        host = urlparse(full).netloc.replace("www.", "")
        if host and host != base_host and not host.endswith("." + base_host):
            continue
        if any(full.lower().endswith(ext) for ext in (".pdf", ".jpg", ".png", ".doc", ".docx")):
            continue
        found.append((full, text or "liste"))
    found += [(urljoin(root, p), p.strip("/")) for p in COMMON_LIST_PATHS]
    seen, out = set(), []
    for url, label in found:
        key = url.rstrip("/")
        if key in seen:
            continue
        seen.add(key)
        out.append((url, label))
    return out[:18]


async def _try_html(client, root: str, home_html: str) -> List[Source]:
    out: List[Source] = []
    for url, label in _list_page_candidates(root, home_html):
        r = await get(client, url)
        if not r or "html" not in r.headers.get("content-type", "text/html"):
            continue
        items = extract.from_html_list(r.text, str(r.url))
        if len(items) >= 3:
            s, n, ratio = _score(items)
            out.append(Source(url=str(r.url), kind="html", score=s, item_count=n,
                              dated_ratio=ratio, label=label[:60],
                              sample=[i.title for i in items[:3]]))
    return out


async def _try_render(root: str, home_html: str) -> List[Source]:
    """JS ile calisan / bot korumali siteler icin gercek tarayiciyla dene."""
    from .adapters import render_html

    rendered_home = await render_html(root)
    if not rendered_home:
        return []
    out: List[Source] = []
    items = extract.from_html_list(rendered_home, root)
    if len(items) >= 3:
        s, n, ratio = _score(items)
        out.append(Source(url=root, kind="render", score=s - 3, item_count=n,
                          dated_ratio=ratio, label="ana sayfa (render)",
                          sample=[i.title for i in items[:3]]))
    for url, label in _list_page_candidates(root, rendered_home or home_html)[:6]:
        html = await render_html(url)
        if not html:
            continue
        items = extract.from_html_list(html, url)
        if len(items) >= 3:
            s, n, ratio = _score(items)
            out.append(Source(url=url, kind="render", score=s + 2, item_count=n,
                              dated_ratio=ratio, label=f"{label[:40]} (render)",
                              sample=[i.title for i in items[:3]]))
    return out


async def discover(client, site: str, max_sources: int = 3,
                   allow_render: bool = True) -> List[Source]:
    r = await get(client, site)
    home_html = r.text if r else ""
    root = str(r.url) if r else site

    candidates: List[Source] = []
    wp = await _try_wp_json(client, root)
    if wp:
        candidates.append(wp)
    candidates += await _try_rss(client, root, home_html)
    candidates += await _try_html(client, root, home_html)

    # Ana sayfanin kendisi de son care olarak liste kaynagi olabilir
    if home_html and not candidates:
        items = extract.from_html_list(home_html, root)
        if len(items) >= 4:
            s, n, ratio = _score(items)
            candidates.append(Source(url=root, kind="html", score=s - 5, item_count=n,
                                     dated_ratio=ratio, label="ana sayfa",
                                     sample=[i.title for i in items[:3]]))

    if not candidates and allow_render:
        candidates += await _try_render(root, home_html)

    candidates.sort(key=lambda c: c.score, reverse=True)
    chosen: List[Source] = []
    seen_urls = set()
    for c in candidates:
        key = c.url.rstrip("/")
        if key in seen_urls:
            continue
        seen_urls.add(key)
        chosen.append(c)
        if len(chosen) >= max_sources:
            break
    return chosen


async def discover_all(federations, concurrency: int = 6,
                       allow_render: bool = True) -> Dict[str, List[dict]]:
    sem = asyncio.Semaphore(concurrency)
    result: Dict[str, List[dict]] = {}

    async with make_client() as client:
        async def one(fed):
            async with sem:
                try:
                    sources = await discover(client, fed.site, allow_render=allow_render)
                except Exception as exc:
                    print(f"  ! {fed.slug}: {type(exc).__name__}: {exc}", flush=True)
                    sources = []
                result[fed.slug] = [asdict(s) for s in sources]
                top = sources[0] if sources else None
                print(f'{fed.slug:22} {"OK " if top else "-- "}'
                      f'{(top.kind + " " + top.url) if top else "kaynak bulunamadi"}', flush=True)

        await asyncio.gather(*[one(f) for f in federations])
    return result
