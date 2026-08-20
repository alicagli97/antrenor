# -*- coding: utf-8 -*-
"""Her federasyonun faaliyet takvimi kaynagini bulur -> data/calendars.json"""
import asyncio, json, pathlib, sys, warnings
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import calendars as cal
from app.scraper.http_client import get, make_client
from app.scraper.registry import FEDERATIONS

OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "calendars.json"
AYRINTI = "--debug" in sys.argv          # aday aday karar dokumu


def iz(*args):
    if AYRINTI:
        print("   ", *args, flush=True)


async def bir_federasyon(client, fed, sem):
    async with sem:
        r = await get(client, fed.site)
        if not r:
            print(f"{fed.slug:22} -- site acilmadi", flush=True)
            return fed.slug, []

        adaylar = cal.aday_baglantilar(str(r.url), r.text)
        # Menude gorunmeyen ama var olan yaygin takvim adresleri
        from urllib.parse import urljoin as _birlestir
        mevcut_urller = {u.rstrip("/") for u, _ in adaylar}
        for yol in cal.YAYGIN_TAKVIM_YOLLARI:
            aday = _birlestir(str(r.url), yol)
            if aday.rstrip("/") not in mevcut_urller:
                adaylar.append((aday, f"yaygın yol {yol}"))

        # Bir kademe derin: takvim sayfasi cogu zaman belgeye baglanti veriyor
        derin = []
        for url, etiket in adaylar[:5]:
            if cal.belge_turu(url):
                continue
            alt = await get(client, url)
            if not alt:
                continue
            mevcut = {a.rstrip("/") for a, _ in adaylar}
            for u2, e2 in cal.aday_baglantilar(str(alt.url), alt.text)[:6]:
                if u2.rstrip("/") not in mevcut:
                    derin.append((u2, f"{etiket} > {e2}"))
            # Takvim sozcugu geçen bir sayfaya geldiysek, oradaki belgeler de aday:
            # cogu federasyon duyuru sayfasina PDF ekliyor ve baglanti metni
            # "buraya tiklayiniz" gibi oluyor.
            from bs4 import BeautifulSoup
            from urllib.parse import urljoin as _join
            icerik = BeautifulSoup(alt.text, "lxml")
            for a in icerik.find_all("a", href=True):
                tam = _join(str(alt.url), a["href"])
                if not cal.belge_turu(tam) or tam.rstrip("/") in mevcut:
                    continue
                # Sayfadaki her belge takvim degil: KVKK metni, form, logo eleniyor
                if any(k in cal._lower_tr(tam) for k in cal.TAKVIM_DISI):
                    continue
                derin.append((tam, f"{etiket} > belge"))
        adaylar = adaylar + derin[:8]

        bulunan = []
        from urllib.parse import urlparse as _parse
        for url, etiket in adaylar:
            # Sitenin ana sayfasi takvim kaynagi olamaz
            if _parse(url).path.strip("/") == "":
                continue
            imza = f"{etiket} {url}"
            if cal.eski_mi(etiket, url):                # 2016, 2017... arsiv
                iz("ELENDI eski yil:", url[:70]); continue
            tur = cal.belge_turu(url) or "html"
            # Belgelerde isaret DOSYA ADINDA aranir: derin adaylar ust sayfanin
            # etiketini devraldigi icin "Yarisma Takvimi > belge" gibi bir etiket
            # veli izin formunu da takvim gosterebiliyor.
            if tur != "html":
                dosya = cal._lower_tr(url.rstrip("/").rsplit("/", 1)[-1])
                if not any(g in dosya for g in cal.GUCLU_ISARETLER):
                    iz("ELENDI belge adinda takvim isareti yok:", url[:70]); continue
            kaynak = cal.TakvimKaynagi(url=url, tur=tur, label=etiket)
            durum = await cal.kaynak_cek(client, kaynak)
            if not durum:
                iz("ELENDI icerik dogrulanmadi:", url[:70]); continue
            kaynak.event_count = len(durum.etkinlikler)

            # Tek bir etkinligin detay sayfasi takvim sayilmasin: ya satir
            # cikarabilmeliyiz ya da baglanti acikca takvim demeli
            guclu = any(g in cal._lower_tr(imza) for g in cal.GUCLU_ISARETLER)
            if tur == "html" and kaynak.event_count < 5 and not guclu:
                iz("ELENDI az etkinlik:", url[:70]); continue
            # Puan: satir cikarabildiysek yuksek, belge ise orta, bos html dusuk
            # Cok satirli eski bir tablo, guncel bir belgeyi ezmesin
            temel = min(kaynak.event_count, 60) * 1.5 if tur == "html" else 25
            etiket_puani = 10 if ("takvim" in etiket.lower() or "program" in etiket.lower()) else 0
            yil = cal.yil_puani(f"{etiket} {url}")
            kaynak.score = temel + etiket_puani + yil
            iz(f"KABUL puan={kaynak.score:.0f} et={kaynak.event_count}:", url[:70])
            bulunan.append((kaynak, durum, yil < 0))

        # Eski yila ait olanlar ancak baska secenek yoksa kullanilir
        guncel = [(k, d) for k, d, arsiv in bulunan if not arsiv]
        aday = guncel or [(k, d) for k, d, _ in bulunan]
        aday.sort(key=lambda x: x[0].score, reverse=True)
        secilen = [k for k, _ in aday[:2]]
        if secilen:
            ilk = secilen[0]
            print(f"{fed.slug:22} OK {ilk.tur:5} etkinlik={ilk.event_count:3} {ilk.url[:66]}", flush=True)
        else:
            print(f"{fed.slug:22} -- takvim bulunamadi", flush=True)
        return fed.slug, [k.__dict__ for k in secilen]


async def main():
    hedef = [a for a in sys.argv[1:] if not a.startswith("--")] or None
    feds = [f for f in FEDERATIONS if not hedef or f.slug in hedef]
    print(f"takvim kesfi: {len(feds)} kurum\n", flush=True)
    async with make_client() as client:
        sem = asyncio.Semaphore(5)
        sonuc = await asyncio.gather(*[bir_federasyon(client, f, sem) for f in feds])

    mevcut = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    for slug, kaynaklar in sonuc:
        mevcut[slug] = kaynaklar
    OUT.write_text(json.dumps(mevcut, ensure_ascii=False, indent=1), encoding="utf-8")
    bulunan = sum(1 for _, k in sonuc if k)
    print(f"\ntakvimi bulunan: {bulunan}/{len(feds)} -> {OUT}")

asyncio.run(main())
