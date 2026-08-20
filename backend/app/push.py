# -*- coding: utf-8 -*-
"""Firebase Cloud Messaging (HTTP v1) ile bildirim gonderimi.

Iki mod var:

* ``topic`` (varsayilan) — Uygulama, takip ettigi her federasyon icin
  ``fed_<slug>`` FCM konusuna kendisi abone olur. Sunucu hicbir cihaz
  token'i saklamaz; bildirim konuya gonderilir. Daha az kisisel veri
  demek, hem gizlilik hem de magaza formu acisindan daha basit.
* ``token`` — Cihaz token'lari sunucuda tutulur, kisiye ozel gonderim
  yapilir. Ileride "sadece benim sehrimdeki kurslar" gibi kisisellestirme
  gerekirse bu moda gecilir.

Kurulum: pip install google-auth
Ortam: FCM_PROJECT_ID, FCM_CREDENTIALS_JSON (service account json yolu), PUSH_ENABLED=1
"""
from __future__ import annotations

import json
import logging
from typing import Dict, Iterable, List, Optional

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import (FCM_CREDENTIALS_JSON, FCM_PROJECT_ID, PUSH_ENABLED,
                     PUSH_MAX_PER_RUN, PUSH_MODE)
from .models import Announcement, Device, Federation, Follow

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
log = logging.getLogger("antrenor.push")

# Uygulamanin abone olacagi konu adi. Flutter tarafi:
#   FirebaseMessaging.instance.subscribeToTopic("fed_yuzme")
def topic_for(slug: str) -> str:
    return f"fed_{slug}"


def _access_token() -> Optional[str]:
    if not FCM_CREDENTIALS_JSON:
        return None
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except ImportError:
        log.warning("google-auth kurulu degil, push atlandi")
        return None
    creds = service_account.Credentials.from_service_account_file(
        FCM_CREDENTIALS_JSON, scopes=[FCM_SCOPE])
    creds.refresh(Request())
    return creds.token


def targets_for(db: Session, announcement: Announcement) -> List[Device]:
    """token modunda: ilgili federasyonu takip eden cihazlar."""
    rows = db.execute(
        select(Device).join(Follow, Follow.device_id == Device.id)
        .where(Follow.federation_id == announcement.federation_id)
    ).scalars()
    return list({d.id: d for d in rows}.values())


def build_message(announcement: Announcement, fed: Federation, *,
                  token: Optional[str] = None, topic: Optional[str] = None) -> Dict:
    message: Dict = {
        "notification": {
            "title": fed.short or fed.name,
            "body": announcement.title[:180],
        },
        # Uygulama bildirime dokununca dogrudan duyuruya gitsin diye
        "data": {
            "announcement_id": str(announcement.id),
            "federation_slug": fed.slug,
            "category": announcement.category,
            "url": announcement.url,
        },
        "android": {"priority": "high",
                    "notification": {"channel_id": "duyurular"}},
        "apns": {"payload": {"aps": {"sound": "default", "badge": 1}}},
    }
    if token:
        message["token"] = token
    else:
        message["topic"] = topic
    return {"message": message}


def push_items(entries: List[Dict]) -> int:
    """Veritabanindan bagimsiz konu bildirimi.

    GitHub Actions hattinda kullanilir: elimizde ORM nesnesi degil, duz sozluk var.
    entries: {"federation_slug", "federation_short", "title", "id", "url", "category"}
    """
    if not entries:
        return 0
    if not PUSH_ENABLED or not FCM_PROJECT_ID:
        return 0
    access = _access_token()
    if not access:
        return 0

    url = f"https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send"
    headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
    sent = 0
    with httpx.Client(timeout=20) as client:
        for entry in entries[:PUSH_MAX_PER_RUN]:
            payload = {"message": {
                "topic": topic_for(entry["federation_slug"]),
                "notification": {
                    "title": entry.get("federation_short") or entry["federation_slug"],
                    "body": entry["title"][:180],
                },
                "data": {
                    "announcement_id": str(entry.get("id", "")),
                    "federation_slug": entry["federation_slug"],
                    "category": entry.get("category", "duyuru"),
                    "url": entry.get("url", ""),
                },
                "android": {"priority": "high",
                            "notification": {"channel_id": "duyurular"}},
                "apns": {"payload": {"aps": {"sound": "default", "badge": 1}}},
            }}
            try:
                resp = client.post(url, headers=headers, content=json.dumps(payload))
                if resp.status_code < 300:
                    sent += 1
                else:
                    log.warning("push hatasi %s: %s", resp.status_code, resp.text[:200])
            except Exception as exc:
                log.warning("push istegi basarisiz: %s", exc)
    return sent


def send_new(db: Session, announcements: Iterable[Announcement]) -> int:
    """Yeni duyurular icin bildirim gonderir ve gonderilenleri isaretler."""
    pending = [a for a in announcements if not a.notified][:PUSH_MAX_PER_RUN]
    if not pending:
        return 0

    if not PUSH_ENABLED or not FCM_PROJECT_ID:
        # Gelistirme ortami: kuyruk sismesin diye isaretleyip geciyoruz
        for a in pending:
            a.notified = True
        db.commit()
        return 0

    access = _access_token()
    if not access:
        return 0

    url = f"https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send"
    headers = {"Authorization": f"Bearer {access}", "Content-Type": "application/json"}
    sent = 0

    with httpx.Client(timeout=20) as client:
        for ann in pending:
            fed = db.get(Federation, ann.federation_id)
            if fed is None:
                ann.notified = True
                continue

            if PUSH_MODE == "topic":
                payload = build_message(ann, fed, topic=topic_for(fed.slug))
                try:
                    resp = client.post(url, headers=headers, content=json.dumps(payload))
                    if resp.status_code < 300:
                        sent += 1
                    else:
                        log.warning("push hatasi %s: %s", resp.status_code, resp.text[:200])
                except Exception as exc:
                    log.warning("push istegi basarisiz: %s", exc)
            else:
                for device in targets_for(db, ann):
                    payload = build_message(ann, fed, token=device.push_token)
                    try:
                        resp = client.post(url, headers=headers, content=json.dumps(payload))
                        if resp.status_code == 404:      # token gecersiz -> temizle
                            db.delete(device)
                        elif resp.status_code < 300:
                            sent += 1
                    except Exception:
                        continue

            ann.notified = True

    db.commit()
    return sent
