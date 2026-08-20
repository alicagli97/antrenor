# -*- coding: utf-8 -*-
"""Store bakimi: gezinme/menu artigi kayitlari ayikla, ciktilari yeniden uret.

Kaynak degistiginde (or. federasyon adres degistirdi) eski sitenin kayitlari
store'da kalir. Bu betik onlari temizler.

Kullanim:
    python scripts/temizle.py                 # rapor, degisiklik yazmaz
    python scripts/temizle.py --uygula        # temizle ve ciktilari yenile
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.scraper import extract
from app.scraper.registry import BY_SLUG
from ci_update import STORE, build_outputs, kendi_adi_mi, sort_key

# Federasyonun tasindigi eski alan adlari: bu adreslerden gelen kayitlar dusurulur
ESKI_ADRESLER = {
    "aticilik": ["taaf.org.tr"],
}


def ele(record: dict) -> str | None:
    """Kayit dusurulecekse sebebini doner."""
    slug = record.get("federation")
    if slug not in BY_SLUG:
        return "kutukte olmayan federasyon"
    if kendi_adi_mi(slug, record.get("title", "")):
        return "federasyonun kendi adi"
    if not extract._valid_title(record.get("title", "")):
        return "baslik gecerli degil"
    for eski in ESKI_ADRESLER.get(slug, []):
        if eski in record.get("url", ""):
            return f"eski adres: {eski}"
    return None


def main() -> None:
    uygula = "--uygula" in sys.argv
    rows = json.loads(STORE.read_text(encoding="utf-8"))

    kalan, dusen = [], []
    for r in rows:
        sebep = ele(r)
        (dusen if sebep else kalan).append((r, sebep) if sebep else r)

    print(f"toplam {len(rows)} kayit | dusurulecek {len(dusen)}")
    for r, sebep in dusen[:20]:
        print(f'  - [{sebep:26}] {r["federation"]:16} {r["title"][:56]}')

    if not uygula:
        print("\n(deneme calismasi - yazmak icin --uygula)")
        return

    kalan.sort(key=sort_key, reverse=True)
    build_outputs(kalan, {"new": 0, "partial": True, "partial_slugs": ["temizlik"]})
    print(f"\nyazildi: {len(kalan)} kayit")


if __name__ == "__main__":
    main()
