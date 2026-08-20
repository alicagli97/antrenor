# -*- coding: utf-8 -*-
"""Yarisma kurallari / mevzuat kutuphanesini gunceller ve degisikligi bildirir.

Her turda mevzuat sayfasi okunur:
  * Yeni bir talimat eklendiyse   -> akisa "yeni talimat" kaydi
  * Bir talimat listeden ciktiysa -> sessizce listeden dusulur
  * --deep ile belgelerin icerigi de dogrulanir (ayni adreste guncellenen
    PDF'leri yakalamak icin); gunluk calistirilmasi yeterlidir.

Ciktilar:
    docs/api/v1/rules.json            tum federasyonlarin mevzuat kutuphanesi
    docs/api/v1/kural/<slug>.json     federasyon basina belge listesi
"""
from __future__ import annotations

import asyncio
import json
import os
import pathlib
import sys
import warnings
from datetime import datetime, timezone

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import rules as kural
from app.scraper.calendars import parmak_izi
from app.scraper.http_client import get, make_client
from app.scraper.registry import BY_SLUG, ETIKETLER, FEDERATIONS

BASE = pathlib.Path(__file__).resolve().parents[2]
BACKEND = pathlib.Path(__file__).resolve().parents[1]
OUT = BASE / "docs" / "api" / "v1"
YAYIN = OUT / "rules.json"
KAYNAK_DOSYA = BACKEND / "data" / "rules.json"
STORE = OUT / "announcements.json"

ES_ZAMANLI = 5
DERIN = "--deep" in sys.argv
YENI_DUYURU_SINIRI = 5      # bir federasyondan tek turda en fazla kac bildirim


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


def duyuru_kaydi(slug: str, belge: dict, yeni_mi: bool) -> dict:
    fed = BY_SLUG[slug]
    if yeni_mi:
        baslik = f"Yeni mevzuat: {belge['baslik']}"
        ozet = f"{ETIKETLER[slug]} federasyonunda yeni bir talimat/yönetmelik yayımlandı."
    else:
        baslik = f"Mevzuat güncellendi: {belge['baslik']}"
        ozet = (f"{fed.name} mevzuatındaki bu belgenin içeriği değişti. "
                "Yürürlükteki hâli için kaynağa bakın.")
    zaman = now_iso()
    return {
        "id": parmak_izi(f"kural|{slug}|{belge['url']}|{'yeni' if yeni_mi else 'guncel'}")[:16],
        "federation": slug,
        "federation_name": fed.name,
        "federation_short": fed.short,
        "title": baslik[:400],
        "url": belge["url"],
        "summary": ozet,
        "image": None,
        "category": "mevzuat",
        "tags": ["mevzuat", "talimat"] + (["antrenor"] if belge.get("onemli") else []),
        "published_at": zaman,
        "first_seen_at": zaman,
        "source": "mevzuat",
    }


async def bir_federasyon(client, slug: str, kaynaklar: list, onceki: dict, sem):
    async with sem:
        toplam: list[dict] = []
        kaynak_urlleri: list[str] = []

        for ham in kaynaklar[:2]:
            r = await get(client, ham["url"])
            if not r:
                continue
            belgeler = kural.onemli_siralama(
                kural.sayfadaki_belgeler(str(r.url), r.text))
            if len(belgeler) < 2:
                continue
            kaynak_urlleri.append(str(r.url))
            for b in belgeler:
                toplam.append({"baslik": b.baslik, "url": b.url,
                               "tur": b.tur, "onemli": b.onemli})

        if not toplam:
            return slug, None, []

        # Ayni belge iki sayfada da olabilir
        tekil = {}
        for b in toplam:
            tekil.setdefault(b["url"], b)
        belgeler = list(tekil.values())

        eski = onceki.get(slug) or {}
        eski_belgeler = {b["url"]: b for b in eski.get("documents", [])}
        duyurular: list[dict] = []

        # Yeni eklenen belgeler
        yeniler = [b for b in belgeler if b["url"] not in eski_belgeler]
        if eski_belgeler:                       # ilk turda hepsini bildirme
            for b in sorted(yeniler, key=lambda x: (not x["onemli"], x["baslik"]))[:YENI_DUYURU_SINIRI]:
                duyurular.append(duyuru_kaydi(slug, b, yeni_mi=True))

        # Derin kontrol: ayni adreste guncellenen belgeler
        if DERIN:
            for b in belgeler:
                onceki_iz = eski_belgeler.get(b["url"], {}).get("parmak_izi")
                yeni_iz = await kural.belge_parmak_izi(
                    client, kural.KuralBelgesi(baslik=b["baslik"], url=b["url"], tur=b["tur"]))
                b["parmak_izi"] = yeni_iz or onceki_iz or ""
                if onceki_iz and yeni_iz and onceki_iz != yeni_iz:
                    b["guncellendi"] = now_iso()
                    duyurular.append(duyuru_kaydi(slug, b, yeni_mi=False))
                elif eski_belgeler.get(b["url"], {}).get("guncellendi"):
                    b["guncellendi"] = eski_belgeler[b["url"]]["guncellendi"]
        else:
            for b in belgeler:
                onceki_kayit = eski_belgeler.get(b["url"], {})
                b["parmak_izi"] = onceki_kayit.get("parmak_izi", "")
                if onceki_kayit.get("guncellendi"):
                    b["guncellendi"] = onceki_kayit["guncellendi"]

        kayit = {
            "federation": slug,
            "federation_name": BY_SLUG[slug].name,
            "federation_short": BY_SLUG[slug].short,
            "sources": kaynak_urlleri,
            "document_count": len(belgeler),
            "coach_document_count": sum(1 for b in belgeler if b["onemli"]),
            "documents": belgeler,
            "checked_at": now_iso(),
            "list_fingerprint": parmak_izi("|".join(sorted(b["url"] for b in belgeler))),
        }
        return slug, kayit, duyurular


async def main() -> int:
    kaynaklar = yukle(KAYNAK_DOSYA, {})
    onceki = {k["federation"]: k for k in yukle(YAYIN, {}).get("libraries", [])}

    hedef = None
    if "--only" in sys.argv:
        hedef = [s.strip() for s in sys.argv[sys.argv.index("--only") + 1].split(",") if s.strip()]

    slugs = [f.slug for f in FEDERATIONS
             if (not hedef or f.slug in hedef) and kaynaklar.get(f.slug)]
    print(f"mevzuat kontrolu: {len(slugs)} kurum{' (derin)' if DERIN else ''}")

    async with make_client() as client:
        sem = asyncio.Semaphore(ES_ZAMANLI)
        sonuc = await asyncio.gather(*[
            bir_federasyon(client, s, kaynaklar[s], onceki, sem) for s in slugs])

    kayitlar, duyurular = [], []
    for slug, kayit, duy in sonuc:
        if kayit:
            kayitlar.append(kayit)
        elif onceki.get(slug):
            kayitlar.append(onceki[slug])       # bu turda okunamadi, eskiyi koru
        duyurular.extend(duy)

    for slug, eski in onceki.items():
        if slug not in {k["federation"] for k in kayitlar}:
            kayitlar.append(eski)

    kayitlar.sort(key=lambda k: k["federation"])
    yaz(YAYIN, {
        "schema_version": 1,
        "generated_at": now_iso(),
        "total_libraries": len(kayitlar),
        "total_documents": sum(k["document_count"] for k in kayitlar),
        "coach_documents": sum(k.get("coach_document_count", 0) for k in kayitlar),
        "changed_in_last_run": sorted({d["federation"] for d in duyurular}),
        "libraries": kayitlar,
    })
    for kayit in kayitlar:
        yaz(OUT / "kural" / f'{kayit["federation"]}.json', kayit)

    if duyurular:
        store = yukle(STORE, [])
        yaz(STORE, duyurular + store)
        print(f"akisa eklenen mevzuat bildirimi: {len(duyurular)}")
        for d in duyurular[:10]:
            print(f'  + {d["federation_short"]:8} {d["title"][:70]}')
        if os.getenv("PUSH_ENABLED") == "1":
            from app.push import push_items
            print("bildirim gonderildi:", push_items([{
                "federation_slug": d["federation"], "federation_short": d["federation_short"],
                "title": d["title"], "id": d["id"], "url": d["url"], "category": "mevzuat",
            } for d in duyurular]))
    else:
        print("mevzuatta degisiklik yok")

    print(f"kutuphane: {len(kayitlar)} | belge: {sum(k['document_count'] for k in kayitlar)} "
          f"| antrenor/hakem belgesi: {sum(k.get('coach_document_count', 0) for k in kayitlar)}")
    return len(duyurular)


if __name__ == "__main__":
    asyncio.run(main())
