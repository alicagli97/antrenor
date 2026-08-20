# -*- coding: utf-8 -*-
"""Aday domainleri tarar: erisilebilirlik, baslik, RSS ve duyuru sayfasi kesfi."""
import asyncio, json, re, sys, pathlib
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from candidates import CANDIDATES

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
HEADERS = {"User-Agent": UA, "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.8"}

DUYURU_WORDS = ["duyuru", "haber", "announcement", "news", "bildiri", "genelge", "talimat"]

async def fetch(client, url):
    try:
        r = await client.get(url, headers=HEADERS, follow_redirects=True, timeout=25.0)
        return r
    except Exception as e:
        return e

def find_feeds(soup, base):
    feeds = []
    for link in soup.find_all("link"):
        t = (link.get("type") or "").lower()
        if "rss" in t or "atom" in t or "xml" in t:
            href = link.get("href")
            if href:
                feeds.append(urljoin(base, href))
    for a in soup.find_all("a", href=True):
        h = a["href"].lower()
        if h.endswith("/feed") or h.endswith("/rss") or "rss.xml" in h or "feed.xml" in h:
            feeds.append(urljoin(base, a["href"]))
    return list(dict.fromkeys(feeds))

def find_duyuru_links(soup, base):
    out = []
    host = urlparse(base).netloc
    for a in soup.find_all("a", href=True):
        text = (a.get_text() or "").strip().lower()
        href = a["href"]
        blob = (text + " " + href).lower()
        if any(w in blob for w in DUYURU_WORDS):
            full = urljoin(base, href)
            if urlparse(full).netloc.endswith(host.replace("www.", "")):
                out.append((text[:60], full))
    seen, res = set(), []
    for t, u in out:
        if u not in seen:
            seen.add(u); res.append({"text": t, "url": u})
    return res[:12]

async def probe_domain(client, slug, domain):
    result = {"slug": slug, "domain": domain, "ok": False}
    for scheme in ("https://", "https://www."):
        url = scheme + domain
        r = await fetch(client, url)
        if isinstance(r, Exception):
            result["error"] = f"{type(r).__name__}: {r}"[:120]
            continue
        result["status"] = r.status_code
        result["final_url"] = str(r.url)
        if r.status_code >= 400:
            continue
        html = r.text
        soup = BeautifulSoup(html, "lxml")
        title = (soup.title.get_text().strip() if soup.title else "")[:120]
        result.update({
            "ok": True,
            "title": title,
            "feeds": find_feeds(soup, str(r.url)),
            "duyuru_links": find_duyuru_links(soup, str(r.url)),
            "bytes": len(html),
        })
        return result
    return result

async def main():
    tasks_in = [(slug, d) for slug, ds in CANDIDATES.items() for d in ds]
    limits = httpx.Limits(max_connections=12)
    async with httpx.AsyncClient(limits=limits, verify=False, http2=False) as client:
        sem = asyncio.Semaphore(12)
        async def run(slug, d):
            async with sem:
                return await probe_domain(client, slug, d)
        results = await asyncio.gather(*[run(s, d) for s, d in tasks_in])
    out = pathlib.Path(__file__).parent / "probe_results.json"
    out.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
    ok = [r for r in results if r.get("ok")]
    print(f"denenen: {len(results)}  erisilen: {len(ok)}")
    for r in sorted(ok, key=lambda x: x["slug"]):
        print(f'{r["slug"]:28} {r["domain"]:32} feeds={len(r["feeds"])} duyuru={len(r["duyuru_links"])} | {r["title"][:60]}')

asyncio.run(main())
