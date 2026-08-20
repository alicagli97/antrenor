# -*- coding: utf-8 -*-
"""Mobil uygulamanin kullandigi REST uclari."""
from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from ..auth import create_token, hash_password, read_token, verify_password
from ..config import SUPPORT_EMAIL
from ..db import get_db
from ..models import (Announcement, DeletionRequest, Device, Federation, Follow,
                      ScrapeRun, User, utcnow)
from .schemas import (AnnouncementOut, DeletionRequestIn, DeviceIn, DeviceOut,
                      FederationOut, FeedOut, FollowIn, LoginIn, RegisterIn,
                      SimpleOut, SourceHealthOut, TokenOut)

router = APIRouter(prefix="/v1")


# --- yardimcilar -------------------------------------------------------------

def current_user(db: Session, authorization: Optional[str]) -> Optional[User]:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    user_id = read_token(authorization.split(" ", 1)[1].strip())
    if not user_id:
        return None
    user = db.get(User, user_id)
    if user is None or user.deleted_at is not None:
        return None
    return user


def require_user(db: Session = Depends(get_db),
                 authorization: Optional[str] = Header(default=None)) -> User:
    user = current_user(db, authorization)
    if user is None:
        raise HTTPException(status_code=401, detail="Oturum gerekli")
    return user


def to_announcement_out(row: Announcement, fed: Federation) -> AnnouncementOut:
    return AnnouncementOut(
        id=row.id,
        federation_slug=fed.slug,
        federation_name=fed.name,
        federation_short=fed.short,
        title=row.title,
        url=row.url,
        summary=row.summary,
        image_url=row.image_url,
        category=row.category,
        tags=[t for t in (row.tags or "").split(",") if t],
        published_at=row.published_at,
        first_seen_at=row.first_seen_at,
    )


# --- federasyonlar -----------------------------------------------------------

@router.get("/federations", response_model=List[FederationOut])
def list_federations(db: Session = Depends(get_db),
                     only_active: bool = Query(True, description="Sadece yayindaki federasyonlar")):
    stats = dict(db.execute(
        select(Announcement.federation_id, func.count(Announcement.id))
        .group_by(Announcement.federation_id)
    ).all())
    last = dict(db.execute(
        select(Announcement.federation_id, func.max(Announcement.published_at))
        .group_by(Announcement.federation_id)
    ).all())

    query = select(Federation).order_by(Federation.name)
    if only_active:
        query = query.where(Federation.active.is_(True))
    out = []
    for fed in db.execute(query).scalars():
        out.append(FederationOut(
            slug=fed.slug, name=fed.name, short=fed.short, site=fed.site,
            branches=[b.strip() for b in (fed.branches or "").split(",") if b.strip()],
            olympic=fed.olympic, para=fed.para, logo_url=fed.logo_url,
            announcement_count=stats.get(fed.id, 0),
            last_announcement_at=last.get(fed.id),
        ))
    return out


# --- duyuru akisi ------------------------------------------------------------

@router.get("/announcements", response_model=FeedOut)
def feed(db: Session = Depends(get_db),
         federation: Optional[str] = Query(None, description="Virgulle federasyon slug listesi"),
         category: Optional[str] = Query(None, description="duyuru|kurs|mevzuat|musabaka|haber"),
         tag: Optional[str] = Query(None, description="antrenor, vize, hakem, kurs ..."),
         q: Optional[str] = Query(None, min_length=2, description="Baslik/ozet arama"),
         since: Optional[datetime] = Query(None, description="Bu tarihten sonrasi"),
         cursor: Optional[int] = Query(None, description="Onceki sayfanin son id degeri"),
         limit: int = Query(30, ge=1, le=100)):
    stmt = select(Announcement, Federation).join(Federation, Announcement.federation_id == Federation.id)

    if federation:
        slugs = [s.strip() for s in federation.split(",") if s.strip()]
        stmt = stmt.where(Federation.slug.in_(slugs))
    if category:
        stmt = stmt.where(Announcement.category == category)
    if tag:
        stmt = stmt.where(Announcement.tags.ilike(f"%{tag}%"))
    if since:
        stmt = stmt.where(Announcement.published_at >= since)
    if q:
        like = f"%{q}%"
        # ilike: PostgreSQL'de buyuk/kucuk harf duyarsiz arama icin sart
        stmt = stmt.where(or_(Announcement.title.ilike(like),
                              Announcement.summary.ilike(like),
                              Announcement.content.ilike(like)))
    if cursor:
        stmt = stmt.where(Announcement.id < cursor)

    stmt = stmt.order_by(Announcement.published_at.desc(), Announcement.id.desc()).limit(limit + 1)
    rows = db.execute(stmt).all()

    items = [to_announcement_out(a, f) for a, f in rows[:limit]]
    next_cursor = rows[limit - 1][0].id if len(rows) > limit and items else None
    return FeedOut(items=items, next_cursor=next_cursor)


@router.get("/announcements/{announcement_id}", response_model=AnnouncementOut)
def announcement_detail(announcement_id: int, db: Session = Depends(get_db)):
    row = db.get(Announcement, announcement_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duyuru bulunamadi")
    fed = db.get(Federation, row.federation_id)
    return to_announcement_out(row, fed)


# --- cihaz kaydi ve takip ----------------------------------------------------

@router.post("/devices", response_model=DeviceOut)
def register_device(payload: DeviceIn, db: Session = Depends(get_db),
                    authorization: Optional[str] = Header(default=None)):
    user = current_user(db, authorization)
    device = db.execute(select(Device).where(Device.push_token == payload.push_token)).scalar_one_or_none()
    if device is None:
        device = Device(push_token=payload.push_token)
        db.add(device)
    device.platform = payload.platform
    device.app_version = payload.app_version
    device.locale = payload.locale
    device.last_seen_at = utcnow()
    if user:
        device.user_id = user.id
    db.flush()

    if payload.follow_slugs:
        _set_follows(db, device, user, payload.follow_slugs)
    db.commit()
    return DeviceOut(id=device.id, platform=device.platform,
                     follow_slugs=_follow_slugs(db, device))


def _follow_slugs(db: Session, device: Device) -> List[str]:
    rows = db.execute(
        select(Federation.slug).join(Follow, Follow.federation_id == Federation.id)
        .where(Follow.device_id == device.id)
    ).scalars()
    return sorted(rows)


def _set_follows(db: Session, device: Device, user: Optional[User], slugs: List[str]) -> None:
    fed_ids = dict(db.execute(select(Federation.slug, Federation.id)
                              .where(Federation.slug.in_(slugs))).all())
    db.execute(delete(Follow).where(Follow.device_id == device.id))
    for slug in slugs:
        fid = fed_ids.get(slug)
        if fid:
            db.add(Follow(device_id=device.id, user_id=user.id if user else None, federation_id=fid))


@router.put("/devices/follows", response_model=DeviceOut)
def update_follows(payload: FollowIn, db: Session = Depends(get_db),
                   authorization: Optional[str] = Header(default=None)):
    if not payload.push_token:
        raise HTTPException(status_code=400, detail="push_token gerekli")
    device = db.execute(select(Device).where(Device.push_token == payload.push_token)).scalar_one_or_none()
    if device is None:
        raise HTTPException(status_code=404, detail="Cihaz kaydi bulunamadi")
    user = current_user(db, authorization)
    _set_follows(db, device, user, payload.follow_slugs)
    db.commit()
    return DeviceOut(id=device.id, platform=device.platform, follow_slugs=_follow_slugs(db, device))


# --- hesap islemleri ---------------------------------------------------------

@router.post("/auth/register", response_model=TokenOut)
def register(payload: RegisterIn, db: Session = Depends(get_db)):
    email = payload.email.lower()
    existing = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if existing and existing.deleted_at is None:
        raise HTTPException(status_code=409, detail="Bu e-posta zaten kayitli")
    if existing:                      # silinmis hesabin e-postasi yeniden kullanilabilir
        db.delete(existing)
        db.flush()
    user = User(email=email, password_hash=hash_password(payload.password),
                display_name=payload.display_name[:120])
    db.add(user)
    db.commit()
    return TokenOut(access_token=create_token(user.id), user_id=user.id,
                    email=user.email, display_name=user.display_name)


@router.post("/auth/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email.lower())).scalar_one_or_none()
    if user is None or user.deleted_at is not None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="E-posta veya parola hatali")
    return TokenOut(access_token=create_token(user.id), user_id=user.id,
                    email=user.email, display_name=user.display_name)


@router.delete("/account", response_model=SimpleOut)
def delete_account(db: Session = Depends(get_db), user: User = Depends(require_user)):
    """Uygulama ici hesap silme - App Store Guideline 5.1.1(v) zorunlulugu.

    Hesap ve baglantili tum kisisel veri (cihaz kayitlari, takipler) gercekten silinir;
    dondurma/pasife alma yapilmaz.
    """
    _purge_user(db, user)
    db.commit()
    return SimpleOut(ok=True, message="Hesabiniz ve tum kisisel verileriniz silindi.")


def _purge_user(db: Session, user: User) -> None:
    device_ids = [d.id for d in db.execute(select(Device).where(Device.user_id == user.id)).scalars()]
    if device_ids:
        db.execute(delete(Follow).where(Follow.device_id.in_(device_ids)))
        db.execute(delete(Device).where(Device.id.in_(device_ids)))
    db.execute(delete(Follow).where(Follow.user_id == user.id))
    db.delete(user)


@router.post("/account/deletion-request", response_model=SimpleOut)
def deletion_request(payload: DeletionRequestIn, db: Session = Depends(get_db)):
    """Web uzerinden hesap silme talebi - Google Play User Data Policy zorunlulugu.

    Uygulamayi yeniden kurmadan, tarayicidan da silme baslatilabilir.
    """
    email = payload.email.lower()
    token = secrets.token_urlsafe(32)
    db.add(DeletionRequest(email=email, token=token, source="web"))
    db.commit()
    # Not: uretimde bu token e-posta ile gonderilir; dogrulama sonrasi silme calisir.
    return SimpleOut(ok=True, message=(
        f"{email} adresine dogrulama baglantisi gonderildi. "
        f"Sorun yasarsaniz {SUPPORT_EMAIL} adresine yazabilirsiniz."))


@router.get("/account/deletion-confirm", response_model=SimpleOut)
def deletion_confirm(token: str, db: Session = Depends(get_db)):
    req = db.execute(select(DeletionRequest).where(DeletionRequest.token == token)).scalar_one_or_none()
    if req is None:
        raise HTTPException(status_code=404, detail="Talep bulunamadi")
    if req.completed_at:
        return SimpleOut(ok=True, message="Bu talep zaten tamamlandi.")
    if req.created_at < utcnow() - timedelta(days=7):
        raise HTTPException(status_code=410, detail="Dogrulama baglantisinin suresi doldu")

    user = db.execute(select(User).where(User.email == req.email)).scalar_one_or_none()
    if user:
        _purge_user(db, user)
    req.confirmed_at = utcnow()
    req.completed_at = utcnow()
    db.commit()
    return SimpleOut(ok=True, message="Hesap ve kisisel veriler silindi.")


# --- saglik / seffaflik ------------------------------------------------------

@router.get("/status/sources", response_model=List[SourceHealthOut])
def source_health(db: Session = Depends(get_db), hours: int = Query(48, ge=1, le=720)):
    """Hangi federasyon kaynaginin calisip calismadigini gosterir."""
    since = utcnow() - timedelta(hours=hours)
    latest = {}
    rows = db.execute(
        select(ScrapeRun).where(ScrapeRun.started_at >= since).order_by(ScrapeRun.started_at.desc())
    ).scalars()
    for run in rows:
        latest.setdefault(run.federation_slug, run)
    return [SourceHealthOut(federation_slug=r.federation_slug, source_url=r.source_url,
                            ok=r.ok, items_found=r.items_found, items_new=r.items_new,
                            error=r.error, finished_at=r.finished_at)
            for r in sorted(latest.values(), key=lambda x: x.federation_slug)]
