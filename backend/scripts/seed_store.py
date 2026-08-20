# -*- coding: utf-8 -*-
"""Mevcut SQLite verisini JSON store'a aktarir (tek seferlik gecis)."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sqlalchemy import select
from app.db import SessionLocal, init_db
from app.models import Announcement, Federation

BASE = pathlib.Path(__file__).resolve().parents[2]
OUT = BASE / "docs" / "api" / "v1" / "announcements.json"

init_db()
with SessionLocal() as db:
    feds = {f.id: f for f in db.execute(select(Federation)).scalars()}
    rows = []
    for a in db.execute(select(Announcement)).scalars():
        fed = feds[a.federation_id]
        rows.append({
            "id": a.fingerprint[:16],
            "federation": fed.slug,
            "federation_name": fed.name,
            "federation_short": fed.short,
            "title": a.title,
            "url": a.url,
            "summary": (a.summary or "")[:600],
            "image": a.image_url,
            "category": a.category,
            "tags": [t for t in (a.tags or "").split(",") if t],
            "published_at": a.published_at.replace(microsecond=0).isoformat() if a.published_at else None,
            "first_seen_at": a.first_seen_at.replace(microsecond=0).isoformat(),
            "source": a.source_kind,
        })

rows.sort(key=lambda r: r["published_at"] or r["first_seen_at"], reverse=True)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"aktarilan: {len(rows)} -> {OUT}")
print(f"boyut: {OUT.stat().st_size/1024:.0f} KB")
