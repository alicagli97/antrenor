# -*- coding: utf-8 -*-
"""Ozel kaynak adaptorleri.

Bazi federasyon siteleri duz HTML sunmuyor:
  * SPA (Angular/React)          -> icerik JS ile geliyor, arka plandaki JSON ucu kullanilir
  * Cloudflare "Bir dakika..."   -> gercek tarayici ile beklenerek gecilir
Render icin:  pip install playwright && python -m playwright install chromium
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Callable, Dict, List, Optional

from . import extract
from .dates import parse_iso
from .http_client import get

RENDER_TIMEOUT_MS = 45_000
DEFAULT_WAIT_MS = 4_000


async def render_html(url: str, wait_selector: Optional[str] = None,
                      wait_ms: int = DEFAULT_WAIT_MS) -> str:
    """Playwright ile sayfayi render eder. Kurulu degilse bos doner.

    Cloudflare dogrulamasi birkac saniye surdugu icin bot korumasi olan
    sitelerde wait_ms yuksek verilmelidir (bkz. ADAPTERS).
    """
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        return ""
    try:
        async with async_playwright() as pw:
            browser = await pw.chromium.launch(
                args=["--disable-blink-features=AutomationControlled"])
            context = await browser.new_context(
                locale="tr-TR", viewport={"width": 1366, "height": 900},
                user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"))
            page = await context.new_page()
            try:
                await page.goto(url, timeout=RENDER_TIMEOUT_MS, wait_until="domcontentloaded")
            except Exception:
                pass
            if wait_selector:
                try:
                    await page.wait_for_selector(wait_selector, timeout=10_000)
                except Exception:
                    pass
            await page.wait_for_timeout(wait_ms)
            html = await page.content()
            await browser.close()
            return html
    except Exception:
        return ""


def rendered_source(url: str, wait_selector: Optional[str] = None,
                    wait_ms: int = DEFAULT_WAIT_MS) -> Callable:
    """SPA / bot korumali liste sayfalari icin adaptor uretir."""
    async def _fetch(_client) -> List[extract.Item]:
        html = await render_html(url, wait_selector, wait_ms)
        return extract.from_html_list(html, url) if html else []
    return _fetch


def json_source(api_url: str, mapper: Callable[[dict], Optional[extract.Item]]) -> Callable:
    """Bilinen JSON ucu olan siteler icin adaptor uretir."""
    async def _fetch(client) -> List[extract.Item]:
        r = await get(client, api_url, expect_json=True)
        if not r:
            return []
        try:
            payload = r.json()
        except Exception:
            return []
        rows = payload if isinstance(payload, list) else (
            payload.get("data") or payload.get("items") or payload.get("result") or [])
        out: List[extract.Item] = []
        for row in rows if isinstance(rows, list) else []:
            if not isinstance(row, dict):
                continue
            item = mapper(row)
            if item and item.title:
                item.category, item.tags = extract.classify(item.title, item.summary)
                out.append(item)
        return out
    return _fetch


# --- federasyona ozel esleyiciler -------------------------------------------

def _thf_news(row: dict) -> Optional[extract.Item]:
    """Turkiye Hentbol Federasyonu - api.thf.org.tr/api/v1/Public/GetNewsAll"""
    title = extract.clean(row.get("newsName"))
    slug = row.get("newsUrl") or ""
    if not title or not slug:
        return None
    return extract.Item(
        title=title,
        url=f"https://thf.org.tr/haber/{slug}",
        summary=extract.clean(row.get("content"))[:600],
        image=row.get("imageUrl") or row.get("newsImage"),
        published_at=parse_iso(row.get("startDate") or row.get("createdDate")),
        source_kind="api",
    )


ADAPTERS: Dict[str, Callable] = {
    # Angular SPA; icerik arka plandaki JSON ucundan gelir
    "hentbol": json_source("https://api.thf.org.tr/api/v1/Public/GetNewsAll", _thf_news),
    # Cloudflare dogrulamasi ~10 sn suruyor
    "basketbol": rendered_source("https://www.tbf.org.tr/haberler", wait_ms=12_000),
    "buzhokeyi": rendered_source("https://www.tbhf.org.tr/news", wait_ms=6_000),
}

# Su an erisilemeyen kaynaklar.
# Not: Bu bir IP konumu meselesi degil - Turkiye'deki bir baglantidan, gercek
# tarayici ile ve tarayici basliklariyla denendiginde de ayni sonuc alindi.
# Site otomatik erisimi tumden reddediyor. Temiz cozum: federasyondan
# duyuru akisi (RSS/JSON) veya izin talep etmek.
BLOCKED_SOURCES: Dict[str, str] = {}
