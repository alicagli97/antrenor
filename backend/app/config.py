# -*- coding: utf-8 -*-
"""Uygulama ayarlari (ortam degiskenleriyle ezilebilir)."""
from __future__ import annotations

import os
import pathlib

BASE_DIR = pathlib.Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(exist_ok=True)

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{(DATA_DIR / 'antrenor.db').as_posix()}")

# Tarama zamanlayicisi API sureciyle birlikte mi calissin?
# Uretimde ayri bir "worker" konteyneri kullanildigi icin API'de kapali tutulur;
# aksi halde her API worker'i ayni siteleri tekrar tekrar tarar.
ENABLE_SCHEDULER = os.getenv("ENABLE_SCHEDULER", "1") == "1"

# Tarama
SCRAPE_INTERVAL_MINUTES = int(os.getenv("SCRAPE_INTERVAL_MINUTES", "30"))
SCRAPE_CONCURRENCY = int(os.getenv("SCRAPE_CONCURRENCY", "6"))
FETCH_DETAIL_PAGES = os.getenv("FETCH_DETAIL_PAGES", "1") == "1"
MAX_ITEMS_PER_SOURCE = int(os.getenv("MAX_ITEMS_PER_SOURCE", "40"))

# CORS: uretimde yalnizca kendi web alan adlariniz
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

# Push (Firebase Cloud Messaging - hem Android hem iOS)
# "topic": uygulama federasyon basina FCM konusuna abone olur, sunucu token saklamaz
#          (daha az kisisel veri -> Veri Guvenligi formu sadelesir)
# "token": cihaz token'lari sunucuda tutulur, hedefli gonderim yapilir
PUSH_MODE = os.getenv("PUSH_MODE", "topic")
FCM_PROJECT_ID = os.getenv("FCM_PROJECT_ID", "")
FCM_CREDENTIALS_JSON = os.getenv("FCM_CREDENTIALS_JSON", "")   # service account dosya yolu
PUSH_ENABLED = os.getenv("PUSH_ENABLED", "0") == "1"
PUSH_MAX_PER_RUN = int(os.getenv("PUSH_MAX_PER_RUN", "50"))

# Kimlik dogrulama
JWT_SECRET = os.getenv("JWT_SECRET", "gelistirme-ortami-icin-degistir")
JWT_TTL_DAYS = int(os.getenv("JWT_TTL_DAYS", "60"))

# Apple Sign in with Apple - hesap silmede token iptali icin
APPLE_TEAM_ID = os.getenv("APPLE_TEAM_ID", "")
APPLE_CLIENT_ID = os.getenv("APPLE_CLIENT_ID", "")
APPLE_KEY_ID = os.getenv("APPLE_KEY_ID", "")
APPLE_PRIVATE_KEY = os.getenv("APPLE_PRIVATE_KEY", "")

# Kurumsal
APP_NAME = os.getenv("APP_NAME", "Antrenör")
SUPPORT_EMAIL = os.getenv("SUPPORT_EMAIL", "destek@antrenorapp.com")
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
