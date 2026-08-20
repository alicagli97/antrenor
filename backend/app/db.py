# -*- coding: utf-8 -*-
"""Veritabani oturumu ve federasyon kutugunun senkronizasyonu."""
from __future__ import annotations

from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import DATABASE_URL
from .models import Base, Federation
from .scraper.registry import FEDERATIONS

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def init_db() -> None:
    Base.metadata.create_all(engine)
    sync_federations()


def sync_federations() -> None:
    """registry.py'deki federasyon listesini veritabanina yansitir."""
    with SessionLocal() as db:
        existing = {f.slug: f for f in db.query(Federation).all()}
        for fed in FEDERATIONS:
            row = existing.get(fed.slug)
            if row is None:
                row = Federation(slug=fed.slug)
                db.add(row)
            row.name = fed.name
            row.short = fed.short
            row.site = fed.site
            row.branches = ", ".join(fed.branches)
            row.olympic = fed.olympic
            row.para = fed.para
            row.active = True
        db.commit()


@contextmanager
def session_scope() -> Session:
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def get_db():
    """FastAPI bagimlilik enjeksiyonu."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
