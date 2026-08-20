# -*- coding: utf-8 -*-
"""Faaliyet takvimlerini kontrol eder, degisenleri duyuru olarak akisa dusurur.

Yil basinda yayinlanan faaliyet programlari yil icinde degisiyor: tarih kayiyor,
yarisma ekleniyor veya iptal oluyor. Bu betik her turda takvim kaynaklarinin
parmak izini karsilastirir; degisiklik varsa

  * docs/api/v1/calendars.json guncellenir (etkinlik listesi + belge baglantisi)
  * akisa "Faaliyet takvimi guncellendi" kaydi eklenir (bildirim de gider)

Kullanim:
    python scripts/ci_calendars.py            # tum federasyonlar
    python scripts/ci_calendars.py --only judo,atletizm
"""
from __future__ import annotations

import asyncio
import json
import os
import pathlib
import sys
import warnings
from dataclasses import asdict
from datetime import datetime, timezone

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import calendars as cal
from app.scraper.http_client import make_client
from app.scraper.registry import BY_SLUG, FEDERATIONS

BASE = pathlib.Path(__file__).resolve().parents[2]
BACKEND = pathlib.Path(__file__).resolve().parents[1]
OUT = BASE / "docs" / "api" / "v1"
DURUM_DOSYA = OUT / "calendars.json"          # yayinlanan takvim verisi
KAYNAK_DOSYA = BACKEND / "data" / "calendars.json"   # kesif ciktisi
STORE = OUT / "announcements.json"

ES_ZAMANLI = 5


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def yukle(path: pathlib.Path, varsayilan):
    if not path.exists():
        return varsayilan
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return varsayilan


def yaz(path: pathlib.Path, veri) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(veri, ensure_ascii=False, indent=1), encoding="utf-8")


TUR_ADI = {"pdf": "PDF", "excel": "Excel dosyası", "word": "Word belgesi", "html": "sayfa"}


def duyuru_kaydi(slug: str, url: str, tur: str, etkinlik_sayisi: int, ilk_mi: bool) -> dict:
    """Takvim degisikligini akistaki duyuru bicimine cevirir."""
    fed = BY_SLUG[slug]
    if ilk_mi:
        baslik = f"{fed.short} faaliyet takvimi yayında"
        ozet = "Federasyonun faaliyet takvimi uygulamaya eklendi."
    else:
        baslik = f"{fed.short} faaliyet takviminde değişiklik"
        ozet = ("Federasyonun faaliyet takvimi güncellendi. Tarih değişikliği, "
                "eklenen veya iptal edilen faaliyet olabilir; kaynağı kontrol edin.")
    if etkinlik_sayisi:
        ozet += f" Takvimde {etkinlik_sayisi} faaliyet listeleniyor."

    zaman = now_iso()
    return {
        "id": cal.parmak_izi(f"takvim|{slug}|{zaman}"),
        "federation": slug,
        "federation_name": fed.name,
        "federation_short": fed.short,
        "title": baslik,
        "url": url,
        "summary": ozet,
        "image": None,
        "category": "takvim",
        "tags": ["takvim", "faaliyet"],
        "published_at": zaman,
        "first_seen_at": zaman,
        "source": f"takvim-{tur}",
    }


async def kontrol_et(client, slug: str, kaynaklar: list, onceki: dict, sem) -> tuple[dict, dict | None]:
    """Bir federasyonun takvimini kontrol eder; (yeni durum, duyuru|None)."""
    async with sem:
        for ham in kaynaklar[:2]:
            kaynak = cal.TakvimKaynagi(url=ham["url"], tur=ham["tur"],
                                       label=ham.get("label", ""))
            durum = await cal.kaynak_cek(client, kaynak)
            if not durum:
                continue

            eski = onceki.get(slug) or {}
            degisti = bool(eski) and eski.get("parmak_izi") != durum.parmak_izi
            ilk_mi = not eski

            kayit = {
                "federation": slug,
                "federation_name": BY_SLUG[slug].name,
                "federation_short": BY_SLUG[slug].short,
                "url": durum.url,
                "type": durum.tur,
                "label": kaynak.label,
                "fingerprint": durum.parmak_izi,
                "event_count": len(durum.etkinlikler),
                "events": [asdict(e) for e in durum.etkinlikler[:400]],
                "checked_at": durum.kontrol_edildi,
                "changed_at": (now_iso() if degisti or ilk_mi
                               else eski.get("changed_at") or now_iso()),
                "parmak_izi": durum.parmak_izi,     # ic kullanim
            }
            duyuru = (duyuru_kaydi(slug, durum.url, durum.tur, len(durum.etkinlikler), ilk_mi)
                      if (degisti or ilk_mi) else None)
            return kayit, duyuru
        return {}, None


async def main() -> int:
    hedef = None
    if "--only" in sys.argv:
        hedef = [s.strip() for s in sys.argv[sys.argv.index("--only") + 1].split(",") if s.strip()]

    kaynaklar = yukle(KAYNAK_DOSYA, {})
    onceki_liste = yukle(DURUM_DOSYA, {}).get("calendars", [])
    onceki = {c["federation"]: c for c in onceki_liste}

    slugs = [f.slug for f in FEDERATIONS if (not hedef or f.slug in hedef) and kaynaklar.get(f.slug)]
    print(f"takvim kontrolu: {len(slugs)} kurum")

    async with make_client() as client:
        sem = asyncio.Semaphore(ES_ZAMANLI)
        sonuc = await asyncio.gather(*[
            kontrol_et(client, s, kaynaklar[s], onceki, sem) for s in slugs])

    kayitlar, duyurular = [], []
    for kayit, duyuru in sonuc:
        if kayit:
            kayitlar.append(kayit)
        if duyuru:
            duyurular.append(duyuru)

    # Kontrol edilemeyenlerin eski kaydi korunur
    kontrol_edilen = {k["federation"] for k in kayitlar}
    for slug, eski in onceki.items():
        if slug not in kontrol_edilen:
            kayitlar.append(eski)

    kayitlar.sort(key=lambda k: k["federation"])
    yaz(DURUM_DOSYA, {
        "schema_version": 1,
        "generated_at": now_iso(),
        "total_calendars": len(kayitlar),
        "total_events": sum(k.get("event_count", 0) for k in kayitlar),
        "changed_in_last_run": [d["federation"] for d in duyurular],
        "calendars": kayitlar,
    })

    # Federasyon basina ayri dosya: uygulama tek takvimi ucuza indirsin
    for kayit in kayitlar:
        yaz(OUT / "takvim" / f'{kayit["federation"]}.json', kayit)

    if duyurular:
        store = yukle(STORE, [])
        store = duyurular + store
        yaz(STORE, store)
        print(f"akisa eklenen takvim bildirimi: {len(duyurular)}")
        for d in duyurular:
            print(f'  + {d["federation_short"]:8} {d["title"]}')

        if os.getenv("PUSH_ENABLED") == "1":
            from app.push import push_items
            gonderilen = push_items([{
                "federation_slug": d["federation"], "federation_short": d["federation_short"],
                "title": d["title"], "id": d["id"], "url": d["url"], "category": "takvim",
            } for d in duyurular])
            print(f"bildirim gonderildi: {gonderilen}")
    else:
        print("takvimlerde degisiklik yok")

    print(f"takvim sayisi: {len(kayitlar)} | toplam etkinlik: "
          f"{sum(k.get('event_count', 0) for k in kayitlar)}")
    return len(duyurular)


if __name__ == "__main__":
    asyncio.run(main())
