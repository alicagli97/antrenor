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
        # Bot korumali sitelerde adapters.render_html ile ayni ayarlar sart
        browser = await pw.chromium.launch(
            args=["--disable-blink-features=AutomationControlled"])
        context = await browser.new_context(
            locale="tr-TR", viewport={"width": 1366, "height": 900},
            user_agent=("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                        "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"))
        page = await context.new_page()

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
            await page.goto(url, timeout=45000, wait_until="domcontentloaded")
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
