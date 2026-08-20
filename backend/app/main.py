# -*- coding: utf-8 -*-
"""Antrenör backend - FastAPI uygulamasi.

Calistirma:  uvicorn app.main:app --reload
Tarama zamanlayicisi uygulama ile birlikte baslar (SCRAPE_INTERVAL_MINUTES).
"""
from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse

from .api.routes import router
from .config import (APP_NAME, CORS_ORIGINS, ENABLE_SCHEDULER, PUBLIC_BASE_URL,
                     SCRAPE_INTERVAL_MINUTES, SUPPORT_EMAIL)
from .db import SessionLocal, init_db
from .push import send_new
from .scraper.pipeline import run_once
from .web import pages

log = logging.getLogger("antrenor")
# httpx her istegi INFO seviyesinde yaziyor; uretimde gurultu yapmasin
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


async def scrape_loop():
    while True:
        try:
            with SessionLocal() as db:
                new_items = await run_once(db)
                log.info("tarama tamam: %s yeni duyuru", len(new_items))
                if new_items:
                    sent = send_new(db, new_items)
                    log.info("bildirim gonderildi: %s", sent)
        except Exception as exc:
            log.exception("tarama hatasi: %s", exc)
        await asyncio.sleep(SCRAPE_INTERVAL_MINUTES * 60)


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    task = asyncio.create_task(scrape_loop()) if ENABLE_SCHEDULER else None
    if task is None:
        log.info("zamanlayici kapali (ayri worker sureci bekleniyor)")
    yield
    if task:
        task.cancel()


app = FastAPI(
    title=f"{APP_NAME} API",
    version="1.0.0",
    description="Türkiye spor federasyonlarının duyurularını tek akışta toplayan servis.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/health")
def health():
    """Yuk dengeleyici icin hafif kontrol."""
    return JSONResponse({"ok": True, "app": APP_NAME})


@app.get("/ready")
def ready():
    """Veritabani ve veri tazeligi kontrolu (dagitim sonrasi dogrulama)."""
    from sqlalchemy import func, select

    from .models import Announcement, ScrapeRun
    with SessionLocal() as db:
        total = db.execute(select(func.count(Announcement.id))).scalar() or 0
        last_run = db.execute(
            select(func.max(ScrapeRun.finished_at))).scalar()
        last_item = db.execute(
            select(func.max(Announcement.first_seen_at))).scalar()
    return JSONResponse({
        "ok": total > 0,
        "duyuru_sayisi": total,
        "son_tarama": last_run.isoformat() if last_run else None,
        "son_duyuru": last_item.isoformat() if last_item else None,
        "zamanlayici": ENABLE_SCHEDULER,
    })


# Store zorunluluklari icin genel erisime acik web sayfalari
@app.get("/hesap-silme", response_class=HTMLResponse)
def account_deletion_page():
    return pages.account_deletion_html()


@app.get("/gizlilik", response_class=HTMLResponse)
def privacy_page():
    return pages.privacy_html()


@app.get("/destek", response_class=HTMLResponse)
def support_page():
    return pages.support_html()


@app.get("/", response_class=HTMLResponse)
def index():
    return pages.index_html(PUBLIC_BASE_URL, SUPPORT_EMAIL)
