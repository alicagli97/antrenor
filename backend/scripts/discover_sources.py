# -*- coding: utf-8 -*-
"""Tum federasyonlar icin duyuru kaynaklarini kesfeder -> data/sources.json"""
import asyncio, json, pathlib, sys, warnings

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
warnings.filterwarnings("ignore")

from app.scraper.discovery import discover_all
from app.scraper.registry import FEDERATIONS

OUT = pathlib.Path(__file__).resolve().parents[1] / "data" / "sources.json"


async def main():
    only = sys.argv[1:] or None
    feds = [f for f in FEDERATIONS if not only or f.slug in only]
    print(f"kesif: {len(feds)} federasyon", flush=True)
    result = await discover_all(feds)
    existing = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    existing.update(result)
    OUT.write_text(json.dumps(existing, ensure_ascii=False, indent=1), encoding="utf-8")
    ok = sum(1 for v in result.values() if v)
    print(f"\nkaynak bulunan: {ok}/{len(feds)}  ->  {OUT}")


asyncio.run(main())
