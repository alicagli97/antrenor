# -*- coding: utf-8 -*-
"""Her federasyonun mevzuat/talimat sayfasini bulur -> data/rules.json"""
import asyncio, json, pathlib, sys, warnings
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import rules as kural
from app.scraper.http_client import get, make_client
from app.scraper.registry import FEDERATIONS

OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "rules.json"
AYRINTI = "--debug" in sys.argv

# Menude gorunmeyen ama sik kullanilan mevzuat adresleri
YAYGIN_YOLLAR = ("/mevzuat", "/talimatlar", "/talimat", "/kurallar", "/yonetmelikler",
                 "/tr/mevzuat", "/tr/talimatlar", "/mevzuat/", "/kurumsal/mevzuat",
                 "/oyun-kurallari", "/yarisma-talimatlari")


def iz(*a):
    if AYRINTI:
        print("   ", *a, flush=True)


async def bir_federasyon(client, fed, sem):
    async with sem:
        r = await get(client, fed.site)
        if not r:
            print(f"{fed.slug:22} -- site acilmadi", flush=True)
            return fed.slug, []

        from urllib.parse import urljoin
        adaylar = kural.aday_sayfalar(str(r.url), r.text)
        mevcut = {u.rstrip("/") for u, _ in adaylar}
        for yol in YAYGIN_YOLLAR:
            aday = urljoin(str(r.url), yol)
            if aday.rstrip("/") not in mevcut:
                adaylar.append((aday, f"yaygın yol {yol}"))

        bulunan = []
        for url, etiket in adaylar:
            if kural.belge_turu(url):        # dogrudan belge: tek basina sayfa degil
                continue
            sayfa = await get(client, url, retries=0)
            if not sayfa:
                iz("ELENDI acilmadi:", url[:70]); continue
            belgeler = kural.sayfadaki_belgeler(str(sayfa.url), sayfa.text)
            if len(belgeler) < 2:
                iz(f"ELENDI belge={len(belgeler)}:", url[:70]); continue
            kaynak = kural.KuralKaynagi(url=str(sayfa.url), label=etiket,
                                        belge_sayisi=len(belgeler),
                                        belgeler=kural.onemli_siralama(belgeler))
            onemli = sum(1 for b in belgeler if b.onemli)
            kaynak.score = len(belgeler) + onemli * 3
            iz(f"KABUL belge={len(belgeler)} onemli={onemli}:", url[:70])
            bulunan.append(kaynak)

        bulunan.sort(key=lambda k: k.score, reverse=True)
        secilen = bulunan[:2]
        if secilen:
            ilk = secilen[0]
            onemli = sum(1 for b in ilk.belgeler if b.onemli)
            print(f"{fed.slug:22} OK belge={ilk.belge_sayisi:3} antrenor/hakem={onemli:2} {ilk.url[:56]}", flush=True)
        else:
            print(f"{fed.slug:22} -- mevzuat bulunamadi", flush=True)

        return fed.slug, [{"url": k.url, "label": k.label, "belge_sayisi": k.belge_sayisi,
                           "score": k.score} for k in secilen]


async def main():
    hedef = [a for a in sys.argv[1:] if not a.startswith("--")] or None
    feds = [f for f in FEDERATIONS if not hedef or f.slug in hedef]
    print(f"mevzuat kesfi: {len(feds)} kurum\n", flush=True)
    async with make_client() as client:
        sem = asyncio.Semaphore(5)
        sonuc = await asyncio.gather(*[bir_federasyon(client, f, sem) for f in feds])

    mevcut = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    for slug, kaynaklar in sonuc:
        mevcut[slug] = kaynaklar
    OUT.write_text(json.dumps(mevcut, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nmevzuati bulunan: {sum(1 for _, k in sonuc if k)}/{len(feds)} -> {OUT}")

asyncio.run(main())
