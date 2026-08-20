# -*- coding: utf-8 -*-
"""Veritabani modelleri (SQLAlchemy 2.x).

Store uyumlulugu notu: kullanici verisi minimumda tutulur. Hesap silme
(App Store 5.1.1(v) ve Google Play User Data Policy) icin User uzerinde
gercek silme yapilir; anonim cihaz kayitlari da silinir.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (Boolean, DateTime, ForeignKey, Index, Integer, String,
                        Text, UniqueConstraint)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class Federation(Base):
    __tablename__ = "federations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(200))
    short: Mapped[str] = mapped_column(String(32), default="")
    site: Mapped[str] = mapped_column(String(300))
    branches: Mapped[str] = mapped_column(Text, default="")     # virgulle ayrilmis
    olympic: Mapped[bool] = mapped_column(Boolean, default=False)
    para: Mapped[bool] = mapped_column(Boolean, default=False)
    logo_url: Mapped[Optional[str]] = mapped_column(String(400), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    announcements: Mapped[list["Announcement"]] = relationship(back_populates="federation")


class Announcement(Base):
    """Federasyon duyurusu. Icerik ozeti saklanir; tam metin icin kaynak linki verilir."""
    __tablename__ = "announcements"
    __table_args__ = (
        UniqueConstraint("fingerprint", name="uq_announcement_fingerprint"),
        Index("ix_announcement_feed", "published_at", "id"),
        Index("ix_announcement_fed_date", "federation_id", "published_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    federation_id: Mapped[int] = mapped_column(ForeignKey("federations.id"), index=True)
    fingerprint: Mapped[str] = mapped_column(String(64), index=True)   # sha1(fed+url|title)
    title: Mapped[str] = mapped_column(String(400))
    url: Mapped[str] = mapped_column(String(800))
    summary: Mapped[str] = mapped_column(Text, default="")
    content: Mapped[str] = mapped_column(Text, default="")             # detaydan cekilen ozet metin
    image_url: Mapped[Optional[str]] = mapped_column(String(800), nullable=True)
    category: Mapped[str] = mapped_column(String(32), default="duyuru", index=True)
    tags: Mapped[str] = mapped_column(String(300), default="")         # virgulle ayrilmis
    published_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), index=True)
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    source_kind: Mapped[str] = mapped_column(String(16), default="html")
    notified: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    federation: Mapped[Federation] = relationship(back_populates="announcements")


class ScrapeRun(Base):
    """Her tarama turunun saglik kaydi; kaynak bozulunca gorunur olsun."""
    __tablename__ = "scrape_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    federation_slug: Mapped[str] = mapped_column(String(64), index=True)
    source_url: Mapped[str] = mapped_column(String(800), default="")
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    ok: Mapped[bool] = mapped_column(Boolean, default=False)
    items_found: Mapped[int] = mapped_column(Integer, default=0)
    items_new: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str] = mapped_column(Text, default="")


class User(Base):
    """E-posta ile kayit. Hesap silme zorunlulugu icin tek kayit noktasi."""
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(120), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    apple_sub: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)  # revoke icin
    apple_refresh_token: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    devices: Mapped[list["Device"]] = relationship(back_populates="user")
    follows: Mapped[list["Follow"]] = relationship(back_populates="user")


class Device(Base):
    """Push icin cihaz kaydi. Kullanicisiz (anonim) da olabilir."""
    __tablename__ = "devices"
    __table_args__ = (UniqueConstraint("push_token", name="uq_device_token"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    push_token: Mapped[str] = mapped_column(String(400))
    platform: Mapped[str] = mapped_column(String(16), default="android")   # android | ios
    app_version: Mapped[str] = mapped_column(String(32), default="")
    locale: Mapped[str] = mapped_column(String(16), default="tr")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[Optional[User]] = relationship(back_populates="devices")


class Follow(Base):
    """Kullanici/cihaz bazli federasyon takibi -> hedefli push."""
    __tablename__ = "follows"
    __table_args__ = (UniqueConstraint("user_id", "device_id", "federation_id",
                                       name="uq_follow_target"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    device_id: Mapped[Optional[int]] = mapped_column(ForeignKey("devices.id"), nullable=True, index=True)
    federation_id: Mapped[int] = mapped_column(ForeignKey("federations.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    user: Mapped[Optional[User]] = relationship(back_populates="follows")


class DeletionRequest(Base):
    """Google Play: web uzerinden de hesap silme talebi alinabilmeli."""
    __tablename__ = "deletion_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), index=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    confirmed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    source: Mapped[str] = mapped_column(String(16), default="web")   # web | app
