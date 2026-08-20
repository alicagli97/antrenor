# -*- coding: utf-8 -*-
"""Domain deseni taramasi: canli federasyon sitelerini bulup KENDI basliklarindan tanimlar."""
import asyncio, itertools, json, pathlib, re, socket, string, sys, unicodedata
from concurrent.futures import ThreadPoolExecutor
import httpx
from bs4 import BeautifulSoup

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from fed_names import FEDERATIONS

HERE = pathlib.Path(__file__).parent
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
H = {"User-Agent": UA, "Accept-Language": "tr-TR,tr;q=0.9"}

def norm(s):
    s = s.lower().replace("ı", "i").replace("ş", "s").replace("ğ", "g") \
                 .replace("ü", "u").replace("ö", "o").replace("ç", "c")
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))

def word_candidates():
    out = set()
    for slug, name, kws in FEDERATIONS:
        base = norm(slug)
        words = [w for w in re.split(r"[^a-z]+", norm(name)) if w and w not in
                 ("turkiye", "federasyonu", "ve", "spor", "sporlari", "turk")]
        initials = "".join(w[0] for w in words)
        forms = {base, "".join(words), initials, "t" + initials + "f", "t" + initials,
                 base + "fed", base + "federasyonu", "turkiye" + base + "federasyonu",
                 "turkiye" + base + "fed", base + "spor"}
        for f in forms:
            if 2 <= len(f) <= 30:
                for tld in (".gov.tr", ".org.tr"):
                    out.add(f + tld)
    return out

def acronym_candidates():
    out = set()
    letters = string.ascii_lowercase
    for a, b in itertools.product(letters, letters):
        out.add(f"t{a}{b}f.gov.tr")
        out.add(f"t{a}{b}f.org.tr")
    for a in letters:
        out.add(f"t{a}f.gov.tr")
        out.add(f"t{a}f.org.tr")
    return out

async def doh(client, host, sem):
    """DNS-over-HTTPS: yerel resolver toplu sorguda tikandigi icin."""
    async with sem:
        for endpoint, params in (
            ("https://dns.google/resolve", {"name": host, "type": "A"}),
            ("https://cloudflare-dns.com/dns-query", {"name": host, "type": "A"}),
        ):
            for _ in range(2):
                try:
                    r = await client.get(endpoint, params=params,
                                         headers={"accept": "application/dns-json"}, timeout=20)
                    if r.status_code == 200:
                        d = r.json()
                        if d.get("Status") == 0 and any(a.get("type") in (1, 5) for a in d.get("Answer", [])):
                            return host
                        if d.get("Status") in (0, 3):
                            return None
                except Exception:
                    await asyncio.sleep(1.0)
        return None

async def dns_sweep(hosts):
    async with httpx.AsyncClient(verify=False, http2=False) as client:
        sem = asyncio.Semaphore(30)
        res = await asyncio.gather(*[doh(client, h, sem) for h in hosts])
    return [h for h in res if h]

async def fetch_title(client, host, sem):
    async with sem:
        for url in (f"https://{host}", f"https://www.{host}", f"http://{host}"):
            try:
                r = await client.get(url, headers=H, timeout=20, follow_redirects=True)
            except Exception:
                continue
            if r.status_code >= 400 or not r.text:
                continue
            soup = BeautifulSoup(r.text, "lxml")
            title = soup.title.get_text(strip=True) if soup.title else ""
            h1 = " ".join(x.get_text(" ", strip=True) for x in soup.find_all("h1")[:2])
            desc = soup.find("meta", attrs={"name": "description"})
            og = soup.find("meta", attrs={"property": "og:site_name"})
            return {"host": host, "url": str(r.url).rstrip("/"), "title": title[:160],
                    "h1": h1[:160],
                    "desc": (desc.get("content") or "")[:200] if desc else "",
                    "site_name": (og.get("content") or "")[:120] if og else "",
                    "bytes": len(r.text)}
        return None

async def main():
    cands = sorted(word_candidates() | acronym_candidates())
    print("aday host:", len(cands), flush=True)
    live = await dns_sweep(cands)
    print("DNS cozulen:", len(live), flush=True)
    (HERE / "dns_live.json").write_text(json.dumps(live, ensure_ascii=False, indent=1), encoding="utf-8")
    async with httpx.AsyncClient(verify=False) as client:
        sem = asyncio.Semaphore(24)
        pages = await asyncio.gather(*[fetch_title(client, h, sem) for h in live])
    pages = [p for p in pages if p]
    print("HTTP yanit veren:", len(pages), flush=True)
    feds = [p for p in pages if "federasyon" in norm(p["title"] + p["h1"] + p["site_name"] + p["desc"])]
    print("federasyon gibi gorunen:", len(feds), flush=True)
    (HERE / "harvest.json").write_text(json.dumps(pages, ensure_ascii=False, indent=1), encoding="utf-8")
    for p in sorted(feds, key=lambda x: x["host"]):
        print(f'{p["host"]:34} {(p["title"] or p["h1"])[:70]}', flush=True)

if __name__ == "__main__":
    asyncio.run(main())
