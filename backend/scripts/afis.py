# -*- coding: utf-8 -*-
"""Anasayfadaki afiş alanını günceller.

Anasayfanın üstündeki kart tamamen sunucudan yönetilir: metni, bağlantısı ve
rengi buradan değişir, uygulamayı güncellemeye gerek kalmaz. Sponsor/duyuru
alanı olarak da kullanılabilir.

Kullanım:
    python scripts/afis.py --goster
    python scripts/afis.py --baslik "Yeni sezon" --metin "..." --url "https://..."
    python scripts/afis.py --kapat
    python scripts/afis.py --ac

Değişiklikten sonra `python scripts/publish.py "afiş güncellendi"` ile yayınlayın.
"""
from __future__ import annotations

import argparse
import json
import pathlib

DOSYA = (pathlib.Path(__file__).resolve().parents[2]
         / "docs" / "api" / "v1" / "banner.json")

VARSAYILAN = {
    "schema_version": 1,
    "aktif": True,
    "tur": "bilgi",            # bilgi | sponsor | uyari
    "baslik": "",
    "metin": "",
    "buton_metni": "",
    "buton_hedefi": "",        # federasyonlar | bildirimler | ayarlar | url
    "url": "",
    "gorsel": "",
    "renk": "#E0A33C",
}


def oku() -> dict:
    if not DOSYA.exists():
        return dict(VARSAYILAN)
    veri = dict(VARSAYILAN)
    veri.update(json.loads(DOSYA.read_text(encoding="utf-8")))
    return veri


def yaz(veri: dict) -> None:
    DOSYA.parent.mkdir(parents=True, exist_ok=True)
    DOSYA.write_text(json.dumps(veri, ensure_ascii=False, indent=1),
                     encoding="utf-8")


def main() -> None:
    ayrıştırıcı = argparse.ArgumentParser(description="Anasayfa afişi")
    ayrıştırıcı.add_argument("--goster", action="store_true", help="mevcut afişi yazdır")
    ayrıştırıcı.add_argument("--ac", action="store_true", help="afişi göster")
    ayrıştırıcı.add_argument("--kapat", action="store_true", help="afişi gizle")
    ayrıştırıcı.add_argument("--tur", choices=["bilgi", "sponsor", "uyari"])
    ayrıştırıcı.add_argument("--baslik")
    ayrıştırıcı.add_argument("--metin")
    ayrıştırıcı.add_argument("--buton")
    ayrıştırıcı.add_argument("--hedef", help="federasyonlar | bildirimler | ayarlar | url")
    ayrıştırıcı.add_argument("--url")
    ayrıştırıcı.add_argument("--gorsel")
    ayrıştırıcı.add_argument("--renk")
    a = ayrıştırıcı.parse_args()

    veri = oku()
    if a.goster:
        print(json.dumps(veri, ensure_ascii=False, indent=1))
        return

    if a.ac:
        veri["aktif"] = True
    if a.kapat:
        veri["aktif"] = False
    for alan, deger in (("tur", a.tur), ("baslik", a.baslik), ("metin", a.metin),
                        ("buton_metni", a.buton), ("buton_hedefi", a.hedef),
                        ("url", a.url), ("gorsel", a.gorsel), ("renk", a.renk)):
        if deger is not None:
            veri[alan] = deger

    yaz(veri)
    print("afiş güncellendi:")
    print(json.dumps(veri, ensure_ascii=False, indent=1))
    print("\nyayınlamak için: python scripts/publish.py \"afiş güncellendi\"")


if __name__ == "__main__":
    main()
