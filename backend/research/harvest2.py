# -*- coding: utf-8 -*-
"""Ikinci tur: hedefli aday domainler + .org/.com.tr varyantlari; sonuclari harvest.json'a ekler."""
import asyncio, json, pathlib, sys
import httpx
from bs4 import BeautifulSoup

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from harvest import doh, fetch_title, norm, word_candidates

HERE = pathlib.Path(__file__).parent

MANUAL = """
tff.org tff.org.tr
tbf.org.tr basketbol.org.tr tbf.gov.tr basketbol.gov.tr
thf.org.tr hentbol.org.tr hentbol.gov.tr thf.gov.tr
tgf.gov.tr gures.org.tr gures.gov.tr turkiyeguresfederasyonu.org.tr guresfederasyonu.org.tr
boks.org.tr boks.gov.tr turkiyeboksfederasyonu.org.tr tbokf.org.tr
tenis.org.tr tenis.gov.tr
tdf.org.tr tdf.gov.tr dagcilik.org.tr dagcilik.gov.tr tirmanis.org.tr
tbrf.org.tr bric.org.tr bridge.org.tr tbf.org
tosfed.org.tr tosfed.com.tr otomobilsporlari.org.tr
tvgf.org.tr tvgf.gov.tr vucutgelistirme.org.tr fitness.gov.tr vucutgelistirme.gov.tr
tkbf.org.tr kickboks.org.tr kickboks.gov.tr turkiyekickboks.org.tr
tbesf.org.tr tbesf.gov.tr bedenselengelliler.org.tr
tiesf.org.tr tiesf.gov.tr isitmeengelliler.org.tr
tgesf.org.tr gormeengelliler.org.tr gesf.org.tr
tossfed.gov.tr tossfed.org.tr ozelsporcular.org.tr
thisf.org.tr hisf.org.tr herkesicinspor.org.tr herkesicinspor.gov.tr
hokey.org.tr hokey.gov.tr thokf.org.tr
okulsporlari.gov.tr okulsporlari.org.tr okulsportr.gov.tr tosf.org.tr
tbgf.org.tr bilekguresi.org.tr bilekguresi.gov.tr
gosbf.org.tr gosb.org.tr gelismekteolansporlar.org.tr
tabff.org.tr ampute.org.tr amputefutbol.org.tr
tsbf.org.tr tekerleklisandalyebasketbol.org.tr
korfbol.org.tr korfbol.gov.tr sutopu.org.tr
buzhokeyi.org.tr tbhf.org.tr buzhokeyi.gov.tr buzpateni.gov.tr
gelenekselsporlar.gov.tr tgsdf.org.tr gelenekselsporlar.org.tr
olimpiyat.org.tr tmok.org.tr paralimpik.org.tr tmpk.org.tr
sportoto.gov.tr gsb.gov.tr shgm.gsb.gov.tr spor.gov.tr sgm.gsb.gov.tr
judo.gov.tr kano.gov.tr eskrim.gov.tr okculuk.gov.tr badminton.gov.tr bisiklet.gov.tr
binicilik.gov.tr triatlon.gov.tr satranc.gov.tr kaykay.gov.tr oryantiring.gov.tr
tmpf.gov.tr tusf.gov.tr thsf.gov.tr tif.gov.tr tmf.gov.tr tbsf.gov.tr taaf.gov.tr
tvf.gov.tr tsf.gov.tr ttf.gov.tr tgf.org tdsf.gov.tr golf.gov.tr
""".split()

def extra_candidates():
    out = set(MANUAL)
    for c in word_candidates():
        stem = c.rsplit(".gov.tr", 1)[0].rsplit(".org.tr", 1)[0]
        out.add(stem + ".org")
        out.add(stem + ".com.tr")
    return out

async def main():
    known = {}
    hp = HERE / "harvest.json"
    if hp.exists():
        known = {p["host"]: p for p in json.loads(hp.read_text(encoding="utf-8"))}
    cands = sorted(h for h in extra_candidates() if h not in known)
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
        print(f'{p["host"]:36} {(p["title"] or p["h1"])[:72]}', flush=True)

asyncio.run(main())
