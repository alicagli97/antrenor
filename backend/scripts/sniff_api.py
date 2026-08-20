# -*- coding: utf-8 -*-
"""SPA sitelerinin arka plandaki JSON uclarini yakalar.

Kullanim: python scripts/sniff_api.py https://thf.org.tr/ [bekleme_saniye]
"""
import asyncio, json, sys, pathlib, warnings
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

KEYS = ("duyur", "haber", "news", "announce", "content", "post")


async def main(url: str, wait: float = 8.0):
    from playwright.async_api import async_playwright
    hits = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch()
        page = await browser.new_page(locale="tr-TR")

        async def on_response(resp):
            ctype = (resp.headers or {}).get("content-type", "")
            if "json" not in ctype:
                return
            try:
                body = await resp.text()
            except Exception:
                return
            hits.append({"url": resp.url, "status": resp.status, "len": len(body),
                         "preview": body[:220]})

        page.on("response", lambda r: asyncio.create_task(on_response(r)))
        try:
            await page.goto(url, timeout=45000, wait_until="networkidle")
        except Exception as exc:
            print("goto:", type(exc).__name__)
        await page.wait_for_timeout(int(wait * 1000))
        title = await page.title()
        text = (await page.inner_text("body"))[:300]
        await browser.close()

    print(f"baslik: {title}")
    print(f"govde ornegi: {text[:200]}")
    print(f"json istek sayisi: {len(hits)}")
    for h in sorted(hits, key=lambda x: -x["len"])[:14]:
        mark = "*" if any(k in h["url"].lower() for k in KEYS) else " "
        print(f' {mark} {h["status"]} {h["len"]:7} {h["url"][:110]}')
        if mark == "*":
            print(f'      {h["preview"][:180]}')


asyncio.run(main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 8.0))
