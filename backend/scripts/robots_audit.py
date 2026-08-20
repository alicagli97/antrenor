# -*- coding: utf-8 -*-
"""robots.txt denetimi.

Kullandigimiz duyuru kaynaklarinin ilgili sitenin robots.txt kurallarina uyup
uymadigini raporlar. Karar vermeyi kolaylastirmak icindir: bir federasyon
duyuru sayfasini robots ile kapatmissa o kaynagi listeden cikarmak
(veya federasyondan izin istemek) gerekir.
"""
import asyncio
import json
import pathlib
import sys
import urllib.robotparser
import warnings
from urllib.parse import urljoin, urlparse

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper.http_client import get, make_client
from app.scraper.pipeline import load_sources
from app.scraper.registry import BY_SLUG

UA = "AntrenorApp"


async def check(client, slug: str, sources: list) -> dict:
    if not sources:
        return {"slug": slug, "durum": "kaynak yok"}
    url = sources[0]["url"]
    if url.startswith("adapter:"):
        url = BY_SLUG[slug].site
    robots_url = urljoin(url, "/robots.txt")
    r = await get(client, robots_url, retries=1)
    if not r or r.status_code >= 400 or "<html" in r.text[:200].lower():
        return {"slug": slug, "url": url, "durum": "robots.txt yok", "izin": True}

    parser = urllib.robotparser.RobotFileParser()
    parser.parse(r.text.splitlines())
    allowed = parser.can_fetch(UA, url)
    delay = parser.crawl_delay(UA)
    return {"slug": slug, "url": url, "durum": "izinli" if allowed else "ENGELLİ",
            "izin": allowed, "crawl_delay": delay}


async def main():
    sources = load_sources()
    async with make_client() as client:
        rows = await asyncio.gather(*[check(client, s, v) for s, v in sources.items()])

    blocked = [r for r in rows if r.get("izin") is False]
    for r in sorted(rows, key=lambda x: x["slug"]):
        print(f'{r["slug"]:24} {r.get("durum",""):14} {r.get("url","")[:70]}')
    print(f"\ntoplam: {len(rows)}   engelli: {len(blocked)}")
    if blocked:
        print("engelli kaynaklar:", [r["slug"] for r in blocked])
    out = pathlib.Path(__file__).resolve().parents[1] / "data" / "robots_audit.json"
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print("rapor:", out)


asyncio.run(main())
