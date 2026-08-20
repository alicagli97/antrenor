# -*- coding: utf-8 -*-
"""API sema tanimlari."""
from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field


class FederationOut(BaseModel):
    slug: str
    name: str
    short: str
    site: str
    branches: List[str]
    olympic: bool
    para: bool
    logo_url: Optional[str] = None
    announcement_count: int = 0
    last_announcement_at: Optional[datetime] = None


class AnnouncementOut(BaseModel):
    id: int
    federation_slug: str
    federation_name: str
    federation_short: str
    title: str
    url: str
    summary: str
    image_url: Optional[str]
    category: str
    tags: List[str]
    published_at: Optional[datetime]
    first_seen_at: datetime


class FeedOut(BaseModel):
    items: List[AnnouncementOut]
    next_cursor: Optional[int] = None
    total_estimate: Optional[int] = None


class DeviceIn(BaseModel):
    push_token: str = Field(min_length=8, max_length=400)
    platform: str = Field(default="android", pattern="^(android|ios)$")
    app_version: str = ""
    locale: str = "tr"
    follow_slugs: List[str] = []


class DeviceOut(BaseModel):
    id: int
    platform: str
    follow_slugs: List[str]


class FollowIn(BaseModel):
    push_token: Optional[str] = None
    follow_slugs: List[str]


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = ""


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str
    display_name: str


class DeletionRequestIn(BaseModel):
    email: EmailStr


class SimpleOut(BaseModel):
    ok: bool
    message: str = ""


class SourceHealthOut(BaseModel):
    federation_slug: str
    source_url: str
    ok: bool
    items_found: int
    items_new: int
    error: str
    finished_at: Optional[datetime]
