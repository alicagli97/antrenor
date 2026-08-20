# -*- coding: utf-8 -*-
"""Tarama isçisi: API'den bagimsiz, tek basina calisan zamanlayici.

Uretimde API birden fazla surecle calistigi icin tarama ayri bir surecte durur;
boylece ayni siteler paralel olarak tekrar tekrar cekilmez.

Calistirma:  python scripts/worker.py
Durdurma:    SIGTERM/Ctrl+C (baslamis tur tamamlanir)
"""
import asyncio
import logging
import pathlib
import signal
import sys
import warnings

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.config import SCRAPE_INTERVAL_MINUTES
from app.db import SessionLocal, init_db
from app.push import send_new
from app.scraper.pipeline import run_once

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("antrenor.worker")
# httpx her istegi INFO seviyesinde yaziyor; uretimde gurultu yapmasin
logging.getLogger("httpx").setLevel(logging.WARNING)

_stop = asyncio.Event()


def _request_stop(*_args) -> None:
    log.info("durdurma sinyali alindi, mevcut tur bitince cikilacak")
    _stop.set()


async def main() -> None:
    init_db()
    log.info("worker basladi, aralik: %s dakika", SCRAPE_INTERVAL_MINUTES)

    while not _stop.is_set():
        try:
            with SessionLocal() as db:
                new_items = await run_once(db)
                log.info("tarama tamam: %s yeni duyuru", len(new_items))
                if new_items:
                    sent = send_new(db, new_items)
                    log.info("bildirim gonderildi: %s", sent)
        except Exception:
            log.exception("tarama turunda hata")

        try:
            await asyncio.wait_for(_stop.wait(), timeout=SCRAPE_INTERVAL_MINUTES * 60)
        except asyncio.TimeoutError:
            pass

    log.info("worker durdu")


if __name__ == "__main__":
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(sig, _request_stop)
        except (ValueError, AttributeError, OSError):
            pass
    asyncio.run(main())
