# -*- coding: utf-8 -*-
"""Link-graf ile federasyon kesfi: bilinen sitelerden diger federasyon domainlerine cikan baglantilari topla."""
import asyncio, json, pathlib, re, sys
import httpx
from bs4 import BeautifulSoup
from urllib.parse import urlparse

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
H = {"User-Agent": UA, "Accept-Language": "tr-TR,tr;q=0.9"}
HERE = pathlib.Path(__file__).parent

SEEDS = [r["final_url"] for r in json.loads((HERE/"probe_results.json").read_text(encoding="utf-8")) if r.get("ok")]
SEEDS += ["https://www.tmok.org.tr", "https://olimpiyat.org.tr/Ulusal-Spor-Federasyonlari",
          "https://www.gosbf.org.tr", "https://tggf.org.tr", "https://tossfed.gov.tr", "https://www.tbesf.org.tr/tr/"]

SKIP = re.compile(r"(facebook|twitter|instagram|youtube|linkedin|google|whatsapp|tiktok|apple|microsoft|adobe|w3\.org|schema\.org|gstatic|jquery|bootstrap)", re.I)

async def grab(client, url):
    try:
        r = await client.get(url, headers=H, follow_redirects=True, timeout=25)
        if r.status_code >= 400: return url, None
        return url, r.text
    except Exception:
        return url, None

def hosts_from(html, src):
    soup = BeautifulSoup(html, "lxml")
    src_host = urlparse(src).netloc.replace("www.", "")
    found = {}
    for a in soup.find_all(["a", "option"]):
        href = a.get("href") or a.get("value") or ""
        if not href.startswith("http"): continue
        h = urlparse(href).netloc.replace("www.", "").lower()
        if not h or h == src_host or SKIP.search(h): continue
        if not (h.endswith(".gov.tr") or h.endswith(".org.tr") or h.endswith(".org") or h.endswith(".com.tr")): continue
        txt = (a.get_text() or "").strip()[:70]
        found.setdefault(h, txt)
    return found

async def main():
    async with httpx.AsyncClient(verify=False) as client:
        sem = asyncio.Semaphore(10)
        async def run(u):
            async with sem: return await grab(client, u)
        pages = await asyncio.gather(*[run(u) for u in dict.fromkeys(SEEDS)])
    all_hosts = {}
    for url, html in pages:
        if not html: continue
        for h, t in hosts_from(html, url).items():
            all_hosts.setdefault(h, {"labels": set(), "seen_on": set()})
            if t: all_hosts[h]["labels"].add(t)
            all_hosts[h]["seen_on"].add(urlparse(url).netloc)
    ser = {h: {"labels": sorted(v["labels"])[:4], "refs": len(v["seen_on"])} for h, v in all_hosts.items()}
    (HERE/"linkgraph.json").write_text(json.dumps(ser, ensure_ascii=False, indent=1), encoding="utf-8")
    print("toplam dis host:", len(ser))
    for h, v in sorted(ser.items(), key=lambda x: -x[1]["refs"]):
        print(f'{v["refs"]:2}  {h:38} {" / ".join(v["labels"])[:70]}')

asyncio.run(main())
