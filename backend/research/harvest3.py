# -*- coding: utf-8 -*-
""".tr uzantisi + yeni bulunan desenlerle ucuncu tur tarama."""
import asyncio, itertools, json, pathlib, string, sys
import httpx

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from harvest import doh, fetch_title, norm, word_candidates

HERE = pathlib.Path(__file__).parent

EXTRA = """
turkboks.gov.tr tvgfbf.gov.tr kickboks.gov.tr tbf.org.tr tgf.tr tdf.tr
turkboks.tr tvgfbf.tr kickboks.tr tbf.tr thf.tr tvf.tr taf.tr tyf.tr tsf.tr tkf.tr tcf.tr
hokey.gov.tr turkiyehokeyfederasyonu.gov.tr thokf.gov.tr
paralimpik.gov.tr tmpk.gov.tr turkiyeparalimpik.org.tr
tabff.gov.tr ampute.gov.tr amputefutbol.gov.tr
tsbf.gov.tr korfbol.gov.tr sutopu.gov.tr buzhokeyi.gov.tr tbhf.gov.tr
tgesf.gov.tr gormeengelliler.gov.tr thisf.gov.tr
okulsporlari.tr osf.gov.tr toksf.gov.tr
tbrf.gov.tr bric.gov.tr bridge.gov.tr
gelenekselsporlar.tr tgsdf.gov.tr geleneksel.gov.tr
""".split()

def tr_candidates():
    out = set(EXTRA)
    for c in word_candidates():
        stem = c.rsplit(".gov.tr", 1)[0].rsplit(".org.tr", 1)[0]
        out.add(stem + ".tr")
    letters = string.ascii_lowercase
    for a, b in itertools.product(letters, letters):
        out.add(f"t{a}{b}f.tr")
    for a in letters:
        out.add(f"t{a}f.tr")
    return out

async def main():
    hp = HERE / "harvest.json"
    known = {p["host"]: p for p in json.loads(hp.read_text(encoding="utf-8"))} if hp.exists() else {}
    cands = sorted(h for h in tr_candidates() if h not in known)
    print("yeni aday:", len(cands), flush=True)
    async with httpx.AsyncClient(verify=False) as client:
        sem = asyncio.Semaphore(40)
        live = [h for h in await asyncio.gather(*[doh(client, h, sem) for h in cands]) if h]
    print("DNS cozulen:", len(live), flush=True)
    async with httpx.AsyncClient(verify=False) as client:
        sem = asyncio.Semaphore(20)
        pages = [p for p in await asyncio.gather(*[fetch_title(client, h, sem) for h in live]) if p]
    print("HTTP yanit:", len(pages), flush=True)
    for p in pages:
        known[p["host"]] = p
    hp.write_text(json.dumps(list(known.values()), ensure_ascii=False, indent=1), encoding="utf-8")
    for p in sorted(pages, key=lambda x: x["host"]):
        t = (p["title"] or p["h1"] or p["site_name"] or "")[:72]
        if "federasyon" in norm(t + p["desc"]) or p["host"].endswith(".tr"):
            print(f'{p["host"]:32} {t}', flush=True)

asyncio.run(main())
