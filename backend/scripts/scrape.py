# -*- coding: utf-8 -*-
"""Tek seferlik tarama: python scripts/scrape.py [slug ...]"""
import asyncio, pathlib, sys, warnings
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.db import SessionLocal, init_db
from app.scraper.pipeline import run_once


async def main():
    init_db()
    slugs = sys.argv[1:] or None
    with SessionLocal() as db:
        new_items = await run_once(db, slugs)
        print(f"\nyeni duyuru: {len(new_items)}")
        for a in new_items[:15]:
            print(f'  [{a.category:9}] {a.title[:80]}')

asyncio.run(main())
