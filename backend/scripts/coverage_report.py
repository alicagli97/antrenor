# -*- coding: utf-8 -*-
"""Kapsama raporu: hangi federasyondan kac duyuru geldi, hangi kaynak calismiyor."""
import json
import pathlib
import sys
from collections import defaultdict

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sqlalchemy import func, select

from app.db import SessionLocal, init_db
from app.models import Announcement, Federation, ScrapeRun
from app.scraper.adapters import ADAPTERS, BLOCKED_SOURCES
from app.scraper.pipeline import load_sources

BASE = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    init_db()
    sources = load_sources()
    with SessionLocal() as db:
        counts = dict(db.execute(
            select(Announcement.federation_id, func.count(Announcement.id))
            .group_by(Announcement.federation_id)).all())
        last_dates = dict(db.execute(
            select(Announcement.federation_id, func.max(Announcement.published_at))
            .group_by(Announcement.federation_id)).all())
        cats = defaultdict(int)
        for cat, n in db.execute(select(Announcement.category, func.count(Announcement.id))
                                 .group_by(Announcement.category)).all():
            cats[cat] = n
        runs = {}
        for run in db.execute(select(ScrapeRun).order_by(ScrapeRun.started_at.desc())).scalars():
            runs.setdefault(run.federation_slug, run)

        feds = list(db.execute(select(Federation).order_by(Federation.name)).scalars())

        rows = []
        for fed in feds:
            src = sources.get(fed.slug) or []
            run = runs.get(fed.slug)
            rows.append({
                "slug": fed.slug,
                "ad": fed.name,
                "site": fed.site,
                "kaynak_turu": ("adapter" if fed.slug in ADAPTERS
                                else (src[0]["kind"] if src else "-")),
                "kaynak_url": (f"adapter:{fed.slug}" if fed.slug in ADAPTERS
                               else (src[0]["url"] if src else "")),
                "duyuru": counts.get(fed.id, 0),
                "son_tarih": last_dates.get(fed.id).strftime("%Y-%m-%d") if last_dates.get(fed.id) else "",
                "son_calisma": "ok" if (run and run.ok) else ("hata" if run else "-"),
                "not": BLOCKED_SOURCES.get(fed.slug, ""),
            })

    total = sum(r["duyuru"] for r in rows)
    working = [r for r in rows if r["duyuru"] > 0]
    empty = [r for r in rows if r["duyuru"] == 0]

    print(f"{'FEDERASYON':46} {'KAYNAK':8} {'DUYURU':>7}  SON")
    print("-" * 78)
    for r in sorted(rows, key=lambda x: -x["duyuru"]):
        print(f'{r["ad"][:45]:46} {r["kaynak_turu"]:8} {r["duyuru"]:>7}  {r["son_tarih"]}')
    print("-" * 78)
    print(f"toplam federasyon : {len(rows)}")
    print(f"veri gelen        : {len(working)}")
    print(f"veri gelmeyen     : {len(empty)}  -> {[r['slug'] for r in empty]}")
    print(f"toplam duyuru     : {total}")
    print(f"kategoriler       : {dict(cats)}")

    out = BASE / "data" / "coverage.json"
    out.write_text(json.dumps({
        "toplam_federasyon": len(rows), "veri_gelen": len(working),
        "toplam_duyuru": total, "kategoriler": dict(cats), "federasyonlar": rows,
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nrapor: {out}")


if __name__ == "__main__":
    main()
