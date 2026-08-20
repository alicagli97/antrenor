# -*- coding: utf-8 -*-
"""Turkce tarih ayristirma: '12 Ağustos 2026', '12.08.2026', ISO 8601 vb."""
from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Optional

TR_MONTHS = {
    "ocak": 1, "şubat": 2, "subat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "mayis": 5,
    "haziran": 6, "temmuz": 7, "ağustos": 8, "agustos": 8, "eylül": 9, "eylul": 9,
    "ekim": 10, "kasım": 11, "kasim": 11, "aralık": 12, "aralik": 12,
}
EN_MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7,
    "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9,
    "oct": 10, "nov": 11, "dec": 12,
}

_NUMERIC = re.compile(r"\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b")
_NUMERIC_REV = re.compile(r"\b(\d{4})[./-](\d{1,2})[./-](\d{1,2})\b")
_TEXTUAL = re.compile(
    r"\b(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s+(\d{4})\b", re.UNICODE)
_TIME = re.compile(r"\b(\d{1,2}):(\d{2})\b")


def _mk(y: int, m: int, d: int, hh: int = 0, mm: int = 0) -> Optional[datetime]:
    try:
        if not (1990 <= y <= 2100 and 1 <= m <= 12 and 1 <= d <= 31):
            return None
        return datetime(y, m, d, hh, mm, tzinfo=timezone.utc)
    except ValueError:
        return None


def parse_tr_date(text: Optional[str]) -> Optional[datetime]:
    """Serbest metinden ilk gecerli tarihi cikarir."""
    if not text:
        return None
    s = " ".join(text.split())[:400]

    hh = mm = 0
    tm = _TIME.search(s)
    if tm:
        hh, mm = int(tm.group(1)), int(tm.group(2))
        if hh > 23 or mm > 59:
            hh = mm = 0

    m = _TEXTUAL.search(s)
    if m:
        month_word = m.group(2).lower()
        month = TR_MONTHS.get(month_word) or EN_MONTHS.get(month_word)
        if month:
            dt = _mk(int(m.group(3)), month, int(m.group(1)), hh, mm)
            if dt:
                return dt

    m = _NUMERIC.search(s)
    if m:
        dt = _mk(int(m.group(3)), int(m.group(2)), int(m.group(1)), hh, mm)
        if dt:
            return dt

    m = _NUMERIC_REV.search(s)
    if m:
        dt = _mk(int(m.group(1)), int(m.group(2)), int(m.group(3)), hh, mm)
        if dt:
            return dt
    return None


def parse_iso(value: Optional[str]) -> Optional[datetime]:
    """RSS/JSON alanlarindaki ISO veya RFC-822 tarihleri."""
    if not value:
        return None
    v = value.strip()
    try:
        dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except ValueError:
        pass
    try:
        from email.utils import parsedate_to_datetime
        dt = parsedate_to_datetime(v)
        if dt:
            return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except Exception:
        pass
    return parse_tr_date(v)
