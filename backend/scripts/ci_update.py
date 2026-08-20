# -*- coding: utf-8 -*-
"""Sunucusuz veri hatti: tara -> birlestir -> JSON yayinla.

GitHub Actions bu betigi saatte bir calistirir. Veritabani yoktur; durum
`docs/api/v1/announcements.json` dosyasinin kendisidir. Yeni duyurular
listenin basina eklenir, boylece git farki kucuk kalir.

Ciktilar (GitHub Pages ile yayinlanir):
    docs/api/v1/meta.json             surum, uretim zamani, sayilar
    docs/api/v1/federations.json      66 kurum + duyuru sayilari
    docs/api/v1/announcements.json    tum duyurular (tam senkron)
    docs/api/v1/feed.json             son 300 duyuru (acilis icin)
    docs/api/v1/fed/<slug>.json       federasyon basina son 60
    docs/api/v1/tag/<etiket>.json     antrenor, vize, hakem ...
    docs/api/v1/category/<kat>.json   kurs, mevzuat, musabaka ...
"""
from __future__ import annotations

import asyncio
import json
import os
import pathlib
import re
import sys
import warnings
from collections import Counter, defaultdict
from datetime import datetime, timezone

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import extract
from app.scraper.pipeline import collect, fingerprint, sane_date
from app.scraper.registry import BY_SLUG, ETIKETLER, FEDERATIONS

BASE = pathlib.Path(__file__).resolve().parents[2]        # depo koku
OUT = BASE / "docs" / "api" / "v1"
STORE = OUT / "announcements.json"

MAX_STORE = 6000          # toplam saklanan duyuru
FEED_SIZE = 300           # acilis akisi
PER_FEDERATION = 60
PER_TAG = 200
SCHEMA_VERSION = 1

EXPORT_TAGS = ["antrenor", "kurs", "vize", "terfi", "hakem", "mevzuat", "kulup", "takvim"]
EXPORT_CATEGORIES = ["kurs", "mevzuat", "musabaka", "duyuru", "haber", "takvim"]


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_store() -> list[dict]:
    if not STORE.exists():
        return []
    try:
        return json.loads(STORE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("uyari: mevcut store bozuk, sifirdan olusturuluyor")
        return []


def _sadelestir(text: str) -> str:
    """Karsilastirma icin: kucuk harf, yalnizca harf/rakam."""
    return re.sub(r"[^a-z0-9çğıöşü]+", "", extract._lower_tr(text))


def kendi_adi_mi(slug: str, title: str) -> bool:
    """Baslik federasyonun kendi adiysa bu bir duyuru degil, logo/anasayfa baglantisidir.

    "Türkiye Oryantiring Federasyonu | TOF" gibi ad + kisaltma birlesimleri de yakalanir.
    """
    fed = BY_SLUG[slug]
    t = _sadelestir(title)
    if not t:
        return True
    adaylar = {_sadelestir(fed.name), _sadelestir(fed.short),
               _sadelestir(fed.name + fed.short),
               _sadelestir(fed.short + fed.name),
               _sadelestir(fed.name + " resmi web sitesi"),
               _sadelestir(fed.name + " anasayfa")}
    return t in adaylar


def to_record(slug: str, item: extract.Item) -> dict:
    fed = BY_SLUG[slug]
    published = sane_date(item.published_at)
    return {
        "id": fingerprint(slug, item)[:16],
        "federation": slug,
        "federation_name": fed.name,
        "federation_short": fed.short,
        "title": item.title[:400],
        "url": item.url[:800],
        "summary": (item.summary or "")[:600]
        if extract.ozet_gecerli_mi(item.summary) else "",
        "image": item.image or None,
        "category": item.category,
        "tags": item.tags,
        "published_at": (published or datetime.now(timezone.utc)).replace(
            microsecond=0).isoformat(),
        "first_seen_at": now_iso(),
        "source": item.source_kind,
    }


def write_json(path: pathlib.Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=1),
                    encoding="utf-8")


def sort_key(record: dict) -> str:
    return record.get("published_at") or record.get("first_seen_at") or ""


def merge_health(stats: dict) -> dict:
    """Kismi tarama kaynak sagligi ozetini bozmasin.

    Yerel kopru yalnizca 1-2 federasyon tarar; bu turun sonucunu genel saglik
    olarak yazarsak "65 kaynaktan 1'i calisiyor" gibi yaniltici bir tablo cikar.
    Kismi turlarda onceki tam taramanin degerleri korunur.
    """
    if not stats.get("partial"):
        return stats
    meta_path = OUT / "meta.json"
    if not meta_path.exists():
        return stats
    try:
        onceki = json.loads(meta_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return stats
    korunan = dict(stats)
    for alan in ("sources_ok", "sources_failed", "sources_empty", "sources_missing"):
        if alan in onceki:
            korunan[alan] = onceki[alan]
    return korunan


def build_outputs(store: list[dict], stats: dict) -> None:
    by_fed = defaultdict(list)
    for record in store:
        by_fed[record["federation"]].append(record)

    counts = {slug: len(rows) for slug, rows in by_fed.items()}
    categories = Counter(r["category"] for r in store)

    federations = []
    for fed in FEDERATIONS:
        rows = by_fed.get(fed.slug, [])
        federations.append({
            "slug": fed.slug,
            "name": fed.name,
            "short": fed.short,
            # Resmi kisaltmalar benzersiz degil (TBF yedi federasyon); arayuz
            # bu etiketi kullanir
            "label": ETIKETLER[fed.slug],
            "site": fed.site,
            "branches": fed.branches,
            "olympic": fed.olympic,
            "para": fed.para,
            "announcement_count": len(rows),
            "last_announcement_at": rows[0]["published_at"] if rows else None,
            "topic": f"fed_{fed.slug}",
        })

    stats = merge_health(stats)
    write_json(OUT / "meta.json", {
        "schema_version": SCHEMA_VERSION,
        "generated_at": now_iso(),
        "total": len(store),
        "new_in_last_run": stats.get("new", 0),
        "sources_ok": stats.get("sources_ok", 0),
        "sources_failed": stats.get("sources_failed", []),
        "sources_empty": stats.get("sources_empty", []),
        "sources_missing": stats.get("sources_missing", []),
        "partial_run": stats.get("partial_slugs") or None,
        "latest_published_at": store[0]["published_at"] if store else None,
        "categories": dict(categories),
        "federation_counts": counts,
    })
    write_json(OUT / "federations.json", federations)
    write_json(STORE, store)
    write_json(OUT / "feed.json", store[:FEED_SIZE])

    for slug, rows in by_fed.items():
        write_json(OUT / "fed" / f"{slug}.json", rows[:PER_FEDERATION])

    for tag in EXPORT_TAGS:
        rows = [r for r in store if tag in r.get("tags", [])][:PER_TAG]
        write_json(OUT / "tag" / f"{tag}.json", rows)

    for category in EXPORT_CATEGORIES:
        rows = [r for r in store if r["category"] == category][:PER_TAG]
        write_json(OUT / "category" / f"{category}.json", rows)


def only_slugs() -> list[str] | None:
    """--only basketbol,kickboks  veya  ONLY_SLUGS ortam degiskeni.

    Bot korumasi nedeniyle GitHub sunucusundan erisilemeyen kaynaklar
    yerel makineden beslenirken kullanilir (bkz. scripts/local_bridge.py).
    """
    raw = ""
    if "--only" in sys.argv:
        raw = sys.argv[sys.argv.index("--only") + 1]
    raw = raw or os.getenv("ONLY_SLUGS", "")
    slugs = [s.strip() for s in raw.split(",") if s.strip()]
    return slugs or None


def sadece_yeniden_uret() -> None:
    """Tarama yapmadan store'dan turetilmis dosyalari yeniden uretir.

    Cakisma cozumunde kullanilir: uzak surumle birlestirilen store'dan
    feed/tag/category dosyalarini tutarli sekilde yeniden yazar.
    """
    store = sorted(load_store(), key=sort_key, reverse=True)
    build_outputs(store, {"new": 0, "partial": True, "partial_slugs": ["yeniden-uretim"]})
    print(f"ciktilar yeniden uretildi: {len(store)} kayit")


async def main() -> int:
    store = load_store()
    known = {r["id"] for r in store}
    print(f"mevcut kayit: {len(store)}")

    # Detay sayfasi yalnizca yeni duyurular icin cekilsin diye tam parmak izi seti
    known_full = {r["id"] for r in store}
    hedef = only_slugs()
    if hedef:
        print(f"yalnizca: {', '.join(hedef)}")
    results = await collect(hedef, known_fingerprints={fp for fp in known_full})

    ok = [r for r in results if r.ok]
    failed = sorted({r.slug for r in results if not r.ok and
                     not any(x.ok for x in results if x.slug == r.slug)})

    # Kutukte olup hic sonuc uretmeyen federasyonlar: kaynak kaybini gorunur kilar
    attempted = {r.slug for r in results}
    kutuk = [f.slug for f in FEDERATIONS] if not hedef else hedef
    missing = sorted(s for s in kutuk if s not in attempted)
    empty = sorted({r.slug for r in ok if not r.items} - {r.slug for r in ok if r.items})

    new_records: list[dict] = []
    for result in ok:
        for item in result.items:
            if kendi_adi_mi(result.slug, item.title):
                continue
            record = to_record(result.slug, item)
            if record["id"] in known:
                continue
            known.add(record["id"])
            new_records.append(record)

    print(f"calisan kaynak: {len(ok)}/{len(kutuk)}"
          f"  hata: {failed or '-'}  bos: {empty or '-'}  kaynaksiz: {missing or '-'}")
    print(f"yeni duyuru: {len(new_records)}")

    if new_records:
        store = sorted(new_records + store, key=sort_key, reverse=True)[:MAX_STORE]
    elif store:
        store = sorted(store, key=sort_key, reverse=True)[:MAX_STORE]

    build_outputs(store, {"new": len(new_records),
                          "sources_ok": len(ok),
                          "sources_failed": failed,
                          "sources_empty": empty,
                          "sources_missing": missing,
                          "partial": bool(hedef),
                          "partial_slugs": hedef})

    # Bildirim: yalnizca gercekten yeni olanlar icin
    if new_records and os.getenv("PUSH_ENABLED") == "1":
        from app.push import push_items
        sent = push_items([{
            "federation_slug": r["federation"],
            "federation_short": r["federation_short"],
            "title": r["title"],
            "id": r["id"],
            "url": r["url"],
            "category": r["category"],
        } for r in new_records])
        print(f"bildirim gonderildi: {sent}")

    for record in new_records[:10]:
        print(f'  + [{record["category"]:9}] {record["federation_short"]:8} {record["title"][:60]}')

    return len(new_records)


if __name__ == "__main__":
    if "--rebuild" in sys.argv:
        sadece_yeniden_uret()
        raise SystemExit(0)
    yeni = asyncio.run(main())
    print(f"\ntamam. yeni kayit: {yeni}")
