# -*- coding: utf-8 -*-
"""Kayitli duyurularin kategori/etiketlerini guncel kurallarla yeniden hesaplar."""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from sqlalchemy import select
from app.db import SessionLocal, init_db
from app.models import Announcement
from app.scraper.extract import classify

init_db()
with SessionLocal() as db:
    rows = list(db.execute(select(Announcement)).scalars())
    changed = 0
    for row in rows:
        cat, tags = classify(row.title, row.summary,
                             trust_summary=row.source_kind != "html")
        new_tags = ",".join(tags)
        if row.category != cat or row.tags != new_tags:
            row.category, row.tags = cat, new_tags
            changed += 1
    db.commit()
print(f"guncellenen: {changed}/{len(rows)}")
