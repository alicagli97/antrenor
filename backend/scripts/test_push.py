# -*- coding: utf-8 -*-
"""Elle test bildirimi gonderir.

Bildirim hattinin ucundan uca calistigini dogrulamak icin. Normal akista
bildirim yalnizca *yeni* bir duyuru yakalandiginda gidiyor; federasyonlar
gunde birkac duyuru yayimladigi icin "hic gelmedi" ile "gonderecek bir sey
yoktu" birbirine karisabiliyor. Bu script o belirsizligi kaldiriyor.

Kullanim (GitHub Actions "Test bildirimi" is akisi bunu cagirir):
    python backend/scripts/test_push.py --slug atletizm
    python backend/scripts/test_push.py --slug yuzme --baslik "Deneme"

Ortam: FCM_PROJECT_ID, FCM_CREDENTIALS_JSON, PUSH_ENABLED=1
"""
from __future__ import annotations

import argparse
import pathlib
import sys
from datetime import datetime

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.config import FCM_PROJECT_ID, PUSH_ENABLED  # noqa: E402
from app.push import push_items, topic_for  # noqa: E402
from app.scraper.registry import BY_SLUG, ETIKETLER  # noqa: E402


def main() -> int:
    cozumleyici = argparse.ArgumentParser(description="Test bildirimi gonder")
    cozumleyici.add_argument("--slug", default="atletizm",
                            help="federasyon slug'i (varsayilan: atletizm)")
    cozumleyici.add_argument("--baslik", default="",
                            help="bildirim metni; bos birakilirsa saat yazilir")
    args = cozumleyici.parse_args()

    if args.slug not in BY_SLUG:
        print(f"bilinmeyen federasyon: {args.slug}")
        return 2
    if not PUSH_ENABLED or not FCM_PROJECT_ID:
        print("push kapali: PUSH_ENABLED / FCM_PROJECT_ID eksik")
        return 2

    metin = args.baslik or (
        f"Test bildirimi — {datetime.now().strftime('%d.%m.%Y %H:%M')}")

    print(f"konu     : {topic_for(args.slug)}")
    print(f"federasyon: {ETIKETLER[args.slug]}")
    print(f"metin    : {metin}")

    gonderilen = push_items([{
        "federation_slug": args.slug,
        "federation_short": ETIKETLER[args.slug],
        "title": metin,
        "id": "test",
        "url": BY_SLUG[args.slug].site,
        "category": "duyuru",
    }])

    if gonderilen:
        print("FCM kabul etti. Cihaza dusmezse sorun uygulama tarafinda:"
              " bildirim izni, konu aboneligi veya pil optimizasyonu.")
        return 0
    print("FCM gonderimi basarisiz — yukaridaki uyarilara bakin.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
