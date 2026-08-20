# -*- coding: utf-8 -*-
"""Her federasyon icin resmi siteyi arama motoru + siki dogrulama ile bulur (rate-limit dostu)."""
import asyncio, json, pathlib, random, re, sys, unicodedata
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urlparse, unquote

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from fed_names import FEDERATIONS

HERE = pathlib.Path(__file__).parent
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
H = {"User-Agent": UA, "Accept-Language": "tr-TR,tr;q=0.9"}
BAD = re.compile(r"(duckduckgo|wikipedia|facebook|instagram|twitter|x\.com|youtube|linkedin|sozcu|hurriyet|milliyet|sabah|ntv|trt|wikiwand|blogspot|sahibinden|eksisozluk|mackolik|aa\.com)", re.I)

def norm(s):
    s = s.lower().replace("ı", "i").replace("ş", "s").replace("ğ", "g") \
                 .replace("ü", "u").replace("ö", "o").replace("ç", "c").replace("İ", "i")
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))

async def ddg(client, q):
    for attempt in range(3):
        try:
            r = await client.post("https://lite.duckduckgo.com/lite/", data={"q": q},
                                  headers=H, timeout=30, follow_redirects=True)
            if r.status_code == 200 and "uddg" in r.text or "<a" in r.text:
                soup = BeautifulSoup(r.text, "lxml")
                urls = []
                for a in soup.find_all("a", href=True):
                    h = a["href"]
                    m = re.search(r"uddg=([^&]+)", h)
                    if m:
                        h = unquote(m.group(1))
                    if not h.startswith("http"):
                        continue
                    host = urlparse(h).netloc.lower()
                    if BAD.search(host):
                        continue
                    urls.append(f"{urlparse(h).scheme}://{host}")
                urls = list(dict.fromkeys(urls))
                if urls:
                    return urls[:8]
        except Exception:
            pass
        await asyncio.sleep(4 + attempt * 4 + random.random() * 3)
    return []

async def verify(client, url, keywords, strict=True):
    try:
        r = await client.get(url, headers=H, timeout=25, follow_redirects=True)
        if r.status_code >= 400:
            return None
    except Exception:
        return None
    soup = BeautifulSoup(r.text, "lxml")
    title = soup.title.get_text(strip=True) if soup.title else ""
    h1 = " ".join(x.get_text(" ", strip=True) for x in soup.find_all("h1")[:3])
    header = norm(title + " " + h1 + " " + urlparse(str(r.url)).netloc)
    kw_hit = any(norm(k) in header for k in keywords)
    if strict and not kw_hit:
        return None
    if not kw_hit:
        body = norm(soup.get_text(" ", strip=True)[:3000])
        if not any(norm(k) in body for k in keywords):
            return None
    return {"url": str(r.url).rstrip("/"), "title": title[:140], "status": r.status_code}

async def main():
    out = []
    async with httpx.AsyncClient(verify=False) as client:
        for i, (slug, name, kws) in enumerate(FEDERATIONS, 1):
            cands = await ddg(client, f"{name} resmi site duyurular")
            hit = None
            for c in cands:
                hit = await verify(client, c, kws, strict=True)
                if hit:
                    break
            if not hit:
                for c in cands:
                    hit = await verify(client, c, kws, strict=False)
                    if hit:
                        break
            rec = {"slug": slug, "name": name, "keywords": kws,
                   "url": hit["url"] if hit else None,
                   "title": hit["title"] if hit else None,
                   "candidates": cands[:5]}
            out.append(rec)
            print(f'{i:3}/{len(FEDERATIONS)} {"OK " if hit else "-- "}{slug:28} {rec["url"] or ("? " + ", ".join(cands[:2]))}', flush=True)
            (HERE / "sites.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
            await asyncio.sleep(2.5 + random.random() * 2.5)
    print("cozulen:", sum(1 for r in out if r["url"]), "/", len(out))

asyncio.run(main())
