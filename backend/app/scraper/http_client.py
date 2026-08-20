# -*- coding: utf-8 -*-
"""Ortak HTTP istemcisi: tarayici benzeri baslik, yeniden deneme, nazik hiz siniri."""
from __future__ import annotations

import asyncio
import random
from typing import Optional

import httpx

# Not: UA icinde "bot" gecen istekleri bazi federasyon sitelerinin WAF'i (kano.org.tr,
# kickboks.gov.tr) 403 ile reddediyor. Kimligimizi bu yuzden From/X-Contact
# basliklarinda veriyoruz, UA'yi standart tarayici dizesi olarak birakiyoruz.
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)

HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.9,*/*;q=0.8",
    "Accept-Language": "tr-TR,tr;q=0.9,en;q=0.6",
    # brotli/zstd cozucusu her ortamda olmayabilir; gzip yeterli
    "Accept-Encoding": "gzip, deflate",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
    "Connection": "keep-alive",
    "From": "destek@antrenorapp.com",
    "X-Contact": "Antrenor App - duyuru toplayici - destek@antrenorapp.com",
}

DEFAULT_TIMEOUT = httpx.Timeout(25.0, connect=15.0)


def make_client(**kwargs) -> httpx.AsyncClient:
    """Federasyon sitelerinin cogu eski/zayif TLS kullandigi icin verify=False."""
    params = dict(
        headers=HEADERS,
        timeout=DEFAULT_TIMEOUT,
        follow_redirects=True,
        verify=False,
        limits=httpx.Limits(max_connections=16, max_keepalive_connections=8),
    )
    params.update(kwargs)
    return httpx.AsyncClient(**params)


async def get(client: httpx.AsyncClient, url: str, *, retries: int = 2,
              expect_json: bool = False) -> Optional[httpx.Response]:
    """Hatada sessizce None doner; scraper tek bir site yuzunden durmamali."""
    last_exc = None
    for attempt in range(retries + 1):
        try:
            r = await client.get(url)
            if r.status_code == 429 or 500 <= r.status_code < 600:
                await asyncio.sleep(2 + attempt * 3 + random.random())
                continue
            if r.status_code >= 400:
                return None
            if expect_json:
                ctype = r.headers.get("content-type", "")
                if "json" not in ctype and not r.text.strip().startswith(("[", "{")):
                    return None
            return r
        except Exception as exc:  # ag hatalari, TLS, DNS
            last_exc = exc
            await asyncio.sleep(1 + attempt * 2)
    return None
