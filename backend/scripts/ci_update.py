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
from datetime import datetime, timedelta, timezone

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper import extract
from app.scraper.rules import baslik_copu_mu
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


# --- Kayit duzeltmeleri -----------------------------------------------------
# Kaynaklardan gelen veri her zaman derli toplu degil; asagidaki uc duzeltme
# yayindan once uygulaniyor.

TR_BUYUK = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"
# Kisaltmalar buyuk harf kalmali
KISALTMALAR = {
    "TFF", "TBF", "THF", "TVF", "TJF", "TKF", "TMF", "TSF", "TDF", "GSB", "SGM",
    "TSSF", "TOKI", "TMOK", "AB", "TC", "TR", "U14", "U15", "U16", "U17", "U18",
    "U19", "U20", "U21", "U23", "K-E", "PDF", "SMS", "IPC", "IOC", "WADA",
}


def _tr_kucuk(metin: str) -> str:
    return metin.replace("I", "ı").replace("İ", "i").lower()


# Baglaclar baslik icinde kucuk kalir
KUCUK_KALAN = {"ve", "ile", "veya", "ya", "için", "icin", "de", "da", "ki", "mi"}

# Turkce'de buyuk I -> kucuk ı'dir ve bu Turkce kelimelerde dogru sonuc verir
# (KATILIMCI -> katilimci). Yabanci kelimelerde yanlis: MUAYTHAI -> muaythaı.
# Asagidaki liste yalnizca o istisnalar icin.
YABANCI_DUZELTME = {
    "muaythaı": "muaythai", "junıor": "junior", "prıx": "prix",
    "ıce": "ice", "ındoor": "indoor", "mını": "mini", "sprınt": "sprint",
    "ınternational": "international", "ınvitational": "invitational",
    "champıons": "champions", "quallfıcation": "quallfication",
    "qualıfıcation": "qualification", "wushu": "wushu",
}


def _tr_baslik(metin: str) -> str:
    """Turkce'ye uygun baslik bicimi. Python'un title() metodu I/ı ayrimini
    bozdugu icin kelime kelime yapiliyor."""
    parcalar = []
    for sira, kelime in enumerate(metin.split(" ")):
        cip = kelime.strip(".,;:()[]\"'")
        if not kelime:
            parcalar.append(kelime)
        elif cip in KISALTMALAR or (len(cip) <= 3 and any(c.isdigit() for c in cip)):
            parcalar.append(kelime)
        else:
            kucuk = YABANCI_DUZELTME.get(_tr_kucuk(kelime), _tr_kucuk(kelime))
            if sira and _tr_kucuk(cip) in KUCUK_KALAN:
                parcalar.append(kucuk)
                continue
            ilk = kucuk[0]
            parcalar.append(("İ" if ilk == "i" else ilk.upper()) + kucuk[1:])
    return " ".join(parcalar)


def _yabanci_duzelt(baslik: str) -> str:
    """Turkce I kurali yuzunden bozulmus yabanci kelimeleri onarir."""
    parcalar = []
    for kelime in baslik.split(" "):
        dogru = YABANCI_DUZELTME.get(_tr_kucuk(kelime))
        if dogru and kelime[:1].isupper():
            dogru = dogru[0].upper() + dogru[1:]
        parcalar.append(dogru or kelime)
    return " ".join(parcalar)


def baslik_duzelt(baslik: str) -> str:
    """Tamami buyuk harfle yazilmis basliklari okunur hale getirir.

    Akista kayitlarin bes'te biri BAGIRIR GIBI duruyordu. Kisa basliklara ve
    icinde kucuk harf bulunanlara dokunulmuyor.
    """
    baslik = _yabanci_duzelt(baslik)
    if len(baslik) < 20:
        return baslik
    harfler = [c for c in baslik if c.isalpha()]
    if not harfler or any(c in "abcçdefgğhıijklmnoöprsştuüvyz" for c in harfler):
        return baslik
    return _tr_baslik(baslik)


def tarih_duzelt(metin: str) -> str:
    """Saat dilimi yazilmamis tarihleri Turkiye saatine sabitler.

    Kayitlarin cogunda saat dilimi yoktu; uygulama bunlari UTC sayinca ayni
    gunun duyurulari uc saate kadar yanlis siralanabiliyordu.
    """
    if not metin or metin.endswith("Z") or "+" in metin[10:]:
        return metin
    return metin + "+03:00"


def _tekil_anahtar(record: dict) -> tuple:
    baslik = re.sub(r"\s+", " ", _tr_kucuk(record.get("title", ""))).strip()
    gun = (record.get("published_at") or "")[:10]
    return (record.get("federation"), baslik, gun)


MEVZUAT_ONEKLERI = ("Mevzuat güncellendi: ", "Yeni mevzuat: ")


def cop_kayit_mi(record: dict) -> bool:
    """Belge adi yerine "Devamı...", "Tıklayın" gibi baglanti metni yakalanmis
    mevzuat kayitlari akista anlamsiz duruyordu."""
    baslik = record.get("title", "")
    for onek in MEVZUAT_ONEKLERI:
        if baslik.startswith(onek):
            return baslik_copu_mu(baslik[len(onek):])
    return False


def kayitlari_duzelt(store: list[dict]) -> tuple[list[dict], dict]:
    """Basliklari duzeltir, tarihleri sabitler, tekrar ve cop kayitlari eler."""
    sayac = {"baslik": 0, "tarih": 0, "tekrar": 0, "cop": 0}
    gorulen: dict[tuple, dict] = {}

    for record in store:
        if cop_kayit_mi(record):
            sayac["cop"] += 1
            continue
        yeni_baslik = baslik_duzelt(record.get("title", ""))
        if yeni_baslik != record.get("title"):
            record["title"] = yeni_baslik
            sayac["baslik"] += 1
        for alan in ("published_at", "first_seen_at"):
            duzeltilmis = tarih_duzelt(record.get(alan) or "")
            if duzeltilmis != (record.get(alan) or ""):
                record[alan] = duzeltilmis
                if alan == "published_at":
                    sayac["tarih"] += 1

        anahtar = _tekil_anahtar(record)
        onceki = gorulen.get(anahtar)
        if onceki is None:
            gorulen[anahtar] = record
        else:
            sayac["tekrar"] += 1
            # Ozeti dolu olani tut; esitse ilk goruleni birak
            if len(record.get("summary") or "") > len(onceki.get("summary") or ""):
                gorulen[anahtar] = record

    return list(gorulen.values()), sayac


SESSIZ_GUN = 60


def sessiz_kaynaklar(store: list[dict]) -> list[dict]:
    """Uzun suredir yeni kayit gelmeyen federasyonlar.

    Kaynak teknik olarak "calisiyor" gorunup icerik uretmemeye baslayabiliyor
    (site yapisi degisti, liste bosaldi). Bunu ancak aylar sonra fark ederiz;
    meta.json'a yazarak gorunur kiliyoruz.
    """
    son: dict[str, str] = {}
    for record in store:
        an = record.get("published_at") or ""
        slug = record.get("federation")
        if an and (slug not in son or an > son[slug]):
            son[slug] = an

    esik = (datetime.now(timezone.utc) - timedelta(days=SESSIZ_GUN)).isoformat()
    sessiz = []
    for slug in sorted(BY_SLUG):
        an = son.get(slug)
        if an is None:
            sessiz.append({"federation": slug, "last_published_at": None,
                           "days": None})
        elif an < esik:
            try:
                gun = (datetime.now(timezone.utc)
                       - datetime.fromisoformat(an)).days
            except ValueError:
                gun = None
            sessiz.append({"federation": slug, "last_published_at": an,
                           "days": gun})
    return sessiz


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
        "silent_sources": sessiz_kaynaklar(store),
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
    store, duzeltme = kayitlari_duzelt(sorted(load_store(), key=sort_key,
                                              reverse=True))
    store.sort(key=sort_key, reverse=True)
    build_outputs(store, {"new": 0, "partial": True, "partial_slugs": ["yeniden-uretim"]})
    print(f"ciktilar yeniden uretildi: {len(store)} kayit "
          f"(baslik {duzeltme['baslik']}, tarih {duzeltme['tarih']}, "
          f"elenen tekrar {duzeltme['tekrar']}, elenen cop {duzeltme['cop']})")


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

    store, duzeltme = kayitlari_duzelt(store)
    store.sort(key=sort_key, reverse=True)
    if any(duzeltme.values()):
        print(f"duzeltme: baslik {duzeltme['baslik']}, tarih {duzeltme['tarih']}, "
              f"elenen tekrar {duzeltme['tekrar']}, elenen cop {duzeltme['cop']}")

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
        print(f"bildirim gonderildi: {sent}/{len(new_records)}")
        if sent == 0:
            # Sessiz basarisizlik uzun sure fark edilmedi: yeni duyuru vardi
            # ama tek bildirim gitmiyordu. Artik is akisini kirmiyoruz (veri
            # yayini surmeli) ama Actions ozetinde hata olarak isaretliyoruz.
            print("::error::Yeni duyuru var ama hic bildirim gonderilemedi"
                  " - yukaridaki push hatalarina bakin")

    for record in new_records[:10]:
        print(f'  + [{record["category"]:9}] {record["federation_short"]:8} {record["title"][:60]}')

    return len(new_records)


if __name__ == "__main__":
    if "--rebuild" in sys.argv:
        sadece_yeniden_uret()
        raise SystemExit(0)
    yeni = asyncio.run(main())
    print(f"\ntamam. yeni kayit: {yeni}")
