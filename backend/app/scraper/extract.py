# -*- coding: utf-8 -*-
"""Duyuru cikarimi: RSS, WordPress REST ve genel HTML liste sayfalari."""
from __future__ import annotations

import html as html_mod
import json
import re
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from .dates import parse_iso, parse_tr_date


@dataclass
class Item:
    title: str
    url: str
    published_at: Optional[datetime] = None
    summary: str = ""
    image: Optional[str] = None
    source_kind: str = ""
    raw_date: str = ""
    category: str = "duyuru"
    tags: List[str] = field(default_factory=list)


# --- siniflandirma -----------------------------------------------------------

KEYWORD_TAGS: Dict[str, List[str]] = {
    "antrenor": ["antrenör", "antrenor", "antrenörlük", "kademe", "yardımcı antrenör"],
    "kurs": ["kurs", "kursu", "eğitim semineri", "gelişim semineri", "temel eğitim"],
    "vize": ["vize", "vize semineri", "vize yenileme", "denklik"],
    "terfi": ["terfi", "kademe yükseltme", "üst kademe"],
    "hakem": ["hakem", "gözlemci", "hakem kursu"],
    "mevzuat": ["talimat", "yönetmelik", "ana statü", "genelge", "mevzuat", "resmi gazete"],
    "musabaka": ["müsabaka", "fikstür", "lig", "şampiyona", "turnuva", "kura", "yarışma"],
    "milli_takim": ["milli takım", "kamp", "aday kadro", "seçme"],
    "transfer": ["transfer", "tescil", "lisans", "vize işlemleri"],
    "kulup": ["kulüp", "kulüplerin dikkatine", "spor kulüpleri"],
    "burs": ["burs", "sözleşme", "başvuru", "ilan", "personel alımı"],
}

CATEGORY_HINTS = [
    ("kurs", ["kurs", "seminer", "eğitim", "kademe", "vize"]),
    ("mevzuat", ["talimat", "yönetmelik", "ana statü", "genelge", "mevzuat"]),
    ("musabaka", ["müsabaka", "fikstür", "lig", "şampiyona", "turnuva", "kura"]),
    ("haber", ["haber", "başarı", "madalya", "kazandı", "şampiyon oldu"]),
]


def _lower_tr(s: str) -> str:
    return (s or "").replace("I", "ı").replace("İ", "i").lower()


_WORD_CACHE: Dict[str, re.Pattern] = {}


def _matches(blob: str, word: str) -> bool:
    """Kisa kelimeler kelime siniriyla, uzunlar duz altdizge olarak aranir."""
    if len(word) > 6 and " " not in word:
        return word in blob
    pattern = _WORD_CACHE.get(word)
    if pattern is None:
        pattern = re.compile(rf"(?<![a-zçğıöşü]){re.escape(word)}(?![a-zçğıöşü])")
        _WORD_CACHE[word] = pattern
    return bool(pattern.search(blob))


def classify(title: str, summary: str = "",
             trust_summary: bool = True) -> tuple[str, List[str]]:
    """Baslik agirlikli siniflandirma.

    trust_summary=False, ozetin liste kartindan kazinan cevre metin oldugu
    (menu/spot karisabilir) durumlarda kullanilir; o zaman yalnizca baslik
    dikkate alinir. RSS/WP/API kaynaklarinda ozet duyuruya aittir, guvenilir.
    """
    head = _lower_tr(title)
    blob = _lower_tr(f"{title} {summary}") if trust_summary else head
    tags = [tag for tag, words in KEYWORD_TAGS.items()
            if any(_matches(blob, w) for w in words)]
    category = "duyuru"
    for cat, words in CATEGORY_HINTS:
        if any(_matches(head, w) for w in words):
            category = cat
            break
    if "antrenor" in tags and category in ("duyuru", "haber"):
        category = "kurs"
    return category, tags


# --- yardimcilar -------------------------------------------------------------

def clean(text: Optional[str]) -> str:
    if not text:
        return ""
    text = html_mod.unescape(re.sub(r"<[^>]+>", " ", text))
    return " ".join(text.split())


def _same_site(base: str, url: str) -> bool:
    b, u = urlparse(base).netloc.replace("www.", ""), urlparse(url).netloc.replace("www.", "")
    return not u or u == b or u.endswith("." + b) or b.endswith("." + u)


_JUNK_PATTERNS = re.compile(
    r"^(https?://|www\.)|^[a-z0-9.-]+\.(com|org|gov|net)(\.tr)?/?$"
    r"|tıklayınız|tiklayiniz|buraya tıkla|için tıkla|indir|pdf indir", re.IGNORECASE)

_JUNK_EXACT = ("devamını oku", "read more", "tümü", "daha fazla", "ana sayfa", "iletişim",
               "galeri", "video", "arşiv", "duyurular", "haberler", "giriş yap",
               "tüm duyurular", "tüm haberler", "online işlemler", "site haritası")


def ozet_gecerli_mi(ozet: str) -> bool:
    """Liste sayfasindan kazinan ozetin gercek metin olup olmadigini anlar.

    HTML listelerinde kartin cevresindeki metni ozet olarak aliyoruz; bu bazen
    menu/gezinme yazisi oluyor ve bosluksuz birlesik cikiyor:
    "GuncelDuyurularAgu17U23ErkeklerveKadinlar..." gibi. Boyle metinler
    kullaniciya gosterilmemeli.
    """
    metin = (ozet or "").strip()
    if len(metin) < 25:
        return False
    bosluk_orani = metin.count(" ") / len(metin)
    if bosluk_orani < 0.08:                      # normal Turkce metin ~0.15
        return False
    if re.search(r"\S{35,}", metin):             # cok uzun bosluksuz dizi
        return False
    kelimeler = metin.split()
    if not kelimeler:
        return False
    tek_harf = sum(1 for k in kelimeler if len(k) == 1) / len(kelimeler)
    return tek_harf <= 0.35


def _valid_title(t: str) -> bool:
    """Baslik gibi gorunmeyen menu/link metinlerini eler."""
    if not (12 <= len(t) <= 600):
        return False
    low = _lower_tr(t).strip()
    if low in _JUNK_EXACT:
        return False
    if _JUNK_PATTERNS.search(t):
        return False
    return True


_SENTENCE_END = re.compile(r"(?<=[a-zçğıöşü][.!?…])\s+")

# Liste kartlarindaki tarih rozetleri ve "2 hafta önce" gibi ekler
_LEADING_DATE_BADGE = re.compile(
    r"^\s*(?:\d{1,2}\s*[./-]?\s*)?(?:ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|"
    r"ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)?\s*\d{0,4}\s*[|·•\-–]?\s*",
    re.IGNORECASE)
_TRAILING_RELATIVE = re.compile(
    r"\s*\d+\s*(saniye|dakika|saat|gün|gun|hafta|ay|yıl|yil)\s*önce\.?\s*$", re.IGNORECASE)
_LEADING_NUMBER = re.compile(r"^\s*\d{1,4}\s+(?=[A-Za-zÇĞİÖŞÜçğıöşü])")


def tidy_title(text: str) -> str:
    """Kart icindeki tarih rozetlerini ve goreli zaman eklerini temizler."""
    t = " ".join((text or "").split())
    prev = None
    while prev != t:
        prev = t
        t = _TRAILING_RELATIVE.sub("", t)
        t = _LEADING_NUMBER.sub("", t)
        t = t.strip(" |·•-–—:")
    return t


def split_title(text: str, limit: int = 150) -> tuple[str, str]:
    """Uzun teaser metinlerini baslik + ozet olarak ayirir.

    Bazi siteler liste baglantisinin icine hem basligi hem spot metni koyuyor;
    boyle durumda ilk cumle baslik, kalani ozet olur.
    """
    text = " ".join((text or "").split())
    if len(text) <= limit:
        return text, ""
    parts = _SENTENCE_END.split(text, maxsplit=1)
    head = parts[0].strip()
    rest = parts[1].strip() if len(parts) > 1 else ""
    if 12 <= len(head) <= limit:
        return head, rest
    cut = text.rfind(" ", 0, limit)
    cut = cut if cut > 40 else limit
    return text[:cut].rstrip(" ,;:-") + "…", text[cut:].strip()


def _anchor_title(a) -> str:
    """Baglanti icindeki en olasi baslik: once baslik etiketleri, sonra duz metin."""
    for selector in ("h1", "h2", "h3", "h4", "h5", "h6"):
        el = a.find(selector)
        if el:
            t = clean(el.get_text(" "))
            if _valid_title(t):
                return t
    for el in a.find_all(attrs={"class": True}):
        classes = " ".join(el.get("class") or []).lower()
        if any(k in classes for k in ("title", "baslik", "headline", "haber-adi", "konu")):
            t = clean(el.get_text(" "))
            if _valid_title(t):
                return t
    t = clean(a.get_text(" "))
    if t:
        return t
    img = a.find("img")
    return clean(img.get("alt")) if img else ""


GENERIC_TITLES = ("anasayfa", "ana sayfa", "duyurular", "haberler", "detay",
                  "resmi internet sitesi", "resmi web sitesi", "home", "news")


def is_generic_title(title: str) -> bool:
    t = _lower_tr(title).strip()
    return any(t == g or t.startswith(g + " ") for g in GENERIC_TITLES)


def best_detail_title(html: str) -> str:
    """Detay sayfasindan gercek basligi alir (og:title veya h1)."""
    soup = BeautifulSoup(html, "lxml")
    og = soup.find("meta", attrs={"property": "og:title"})
    candidates = []
    if og and og.get("content"):
        candidates.append(clean(og["content"]))
    h1 = soup.find("h1")
    if h1:
        candidates.append(clean(h1.get_text(" ")))
    if soup.title:
        # "Baslik - Site Adi" kaliplarinda en uzun parca genelde gercek basliktir
        raw = clean(soup.title.get_text())
        parts = [p.strip() for p in re.split(r"\s+[-|–—•]\s+", raw) if p.strip()]
        if parts:
            candidates.append(max(parts, key=len))
    for c in candidates:
        c = tidy_title(c)
        if 12 <= len(c) <= 220:
            return c
    return ""


# --- Baslik tabanli liste ----------------------------------------------------

def _slugify(text: str) -> str:
    t = _lower_tr(text)
    for src, dst in (("ı", "i"), ("ş", "s"), ("ğ", "g"), ("ü", "u"), ("ö", "o"), ("ç", "c")):
        t = t.replace(src, dst)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")[:60]


def from_heading_list(html: str, base_url: str, min_items: int = 3) -> List[Item]:
    """Duyurulari baglantisiz basliklarda (h2/h3) tutan sayfalar icin.

    Bazi federasyon siteleri duyuruyu ayri bir detay sayfasina koymuyor;
    icerik dogrudan liste sayfasinda aciliyor. Bu durumda her duyuruya
    baslikdan uretilen bir cengel (#...) veriyoruz ki tekilleştirme calissin
    ve baglanti dogru sayfayi acsin.
    """
    soup = BeautifulSoup(html, "lxml")
    for bad in soup.find_all(["nav", "header", "footer", "script", "style", "aside"]):
        bad.decompose()

    items: List[Item] = []
    seen = set()
    for level in ("h2", "h3"):
        basliklar = soup.find_all(level)
        if len(basliklar) < min_items:
            continue
        for el in basliklar:
            title = tidy_title(clean(el.get_text(" ")))
            if not _valid_title(title) or title in seen:
                continue
            seen.add(title)

            kapsayici = el.parent
            ctx = clean(kapsayici.get_text(" ")) if kapsayici else ""
            m = _DATE_NEAR.search(ctx)
            raw_date = m.group(1) if m else ""
            summary = clean(ctx.replace(title, " "))[:400]
            image = None
            if kapsayici:
                img = kapsayici.find("img")
                if img and img.get("src"):
                    image = urljoin(base_url, img["src"])
            cat, tags = classify(title, summary, trust_summary=False)
            items.append(Item(title=title,
                              url=f"{base_url.split('#')[0]}#{_slugify(title)}",
                              published_at=parse_tr_date(raw_date), summary=summary,
                              image=image, source_kind="headings", raw_date=raw_date,
                              category=cat, tags=tags))
        if len(items) >= min_items:
            break
    return items


# --- RSS / Atom --------------------------------------------------------------

def from_rss(text: str, base_url: str) -> List[Item]:
    soup = BeautifulSoup(text, "xml")
    items: List[Item] = []
    nodes = soup.find_all("item") or soup.find_all("entry")
    for node in nodes:
        title = clean(node.find("title").get_text() if node.find("title") else "")
        link = ""
        link_tag = node.find("link")
        if link_tag:
            link = clean(link_tag.get_text()) or link_tag.get("href", "")
        if not link and node.find("guid"):
            link = clean(node.find("guid").get_text())
        if not title or not link:
            continue
        date_raw = ""
        for tag in ("pubDate", "published", "updated", "dc:date", "date"):
            el = node.find(tag)
            if el and el.get_text(strip=True):
                date_raw = el.get_text(strip=True)
                break
        desc_el = node.find("description") or node.find("summary") or node.find("content")
        summary = clean(desc_el.get_text() if desc_el else "")[:600]
        cat, tags = classify(title, summary)
        items.append(Item(title=title, url=urljoin(base_url, link),
                          published_at=parse_iso(date_raw), summary=summary,
                          source_kind="rss", raw_date=date_raw, category=cat, tags=tags))
    return items


# --- WordPress REST ----------------------------------------------------------

def from_wp_json(payload, base_url: str) -> List[Item]:
    if isinstance(payload, (str, bytes)):
        try:
            payload = json.loads(payload)
        except Exception:
            return []
    if not isinstance(payload, list):
        return []
    items: List[Item] = []
    for post in payload:
        if not isinstance(post, dict):
            continue
        title = clean((post.get("title") or {}).get("rendered") if isinstance(post.get("title"), dict) else post.get("title"))
        link = post.get("link") or ""
        if not title or not link:
            continue
        excerpt = post.get("excerpt")
        summary = clean(excerpt.get("rendered") if isinstance(excerpt, dict) else excerpt)[:600]
        image = None
        embedded = post.get("_embedded") or {}
        media = embedded.get("wp:featuredmedia") or []
        if media and isinstance(media, list) and isinstance(media[0], dict):
            image = media[0].get("source_url")
        cat, tags = classify(title, summary)
        items.append(Item(title=title, url=urljoin(base_url, link),
                          published_at=parse_iso(post.get("date_gmt") or post.get("date")),
                          summary=summary, image=image, source_kind="wp_json",
                          raw_date=str(post.get("date") or ""), category=cat, tags=tags))
    return items


# --- Genel HTML liste --------------------------------------------------------

_DATE_NEAR = re.compile(
    r"(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{4}[./-]\d{1,2}[./-]\d{1,2}"
    r"|\d{1,2}\s+[A-Za-zÇĞİÖŞÜçğıöşü]+\s+\d{4})")


def _signature(node) -> str:
    """Anchor'in ait oldugu liste kabini icin kaba imza."""
    parts = []
    cur = node
    for _ in range(3):
        cur = cur.parent
        if cur is None or not getattr(cur, "name", None):
            break
        cls = ".".join(sorted((cur.get("class") or [])[:2]))
        parts.append(f"{cur.name}:{cls}")
    return ">".join(reversed(parts))


def from_html_list(html: str, base_url: str, min_items: int = 3) -> List[Item]:
    """Duyuru/haber listesi sayfalarindan tekrar eden baglanti kaliplarini cikarir."""
    soup = BeautifulSoup(html, "lxml")
    for bad in soup.find_all(["nav", "header", "footer", "script", "style", "aside"]):
        bad.decompose()

    groups: Dict[str, List] = defaultdict(list)
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        if not href or href.startswith(("#", "javascript:", "mailto:", "tel:")):
            continue
        full = urljoin(base_url, href)
        if not _same_site(base_url, full):
            continue
        title = _anchor_title(a)
        if not _valid_title(title):
            continue
        groups[_signature(a)].append((a, title, full))

    if not groups:
        return []

    def score(entries) -> float:
        titles = [t for _, t, _ in entries]
        urls = {u for _, _, u in entries}
        if len(urls) < min_items:
            return 0.0
        avg_len = sum(len(t) for t in titles) / len(titles)
        dated = sum(1 for a, _, _ in entries if _DATE_NEAR.search(clean(a.parent.get_text(" ") if a.parent else "")))
        return len(urls) * 1.0 + min(avg_len, 90) / 15 + dated * 1.5

    best_sig = max(groups, key=lambda s: score(groups[s]))
    entries = groups[best_sig]
    if score(entries) == 0.0:
        return []

    items: List[Item] = []
    seen = set()
    for a, title, full in entries:
        if full in seen:
            continue
        seen.add(full)
        ctx = ""
        node = a
        for _ in range(3):
            node = node.parent
            if node is None:
                break
            ctx = clean(node.get_text(" "))
            if _DATE_NEAR.search(ctx):
                break
        m = _DATE_NEAR.search(ctx or "")
        raw_date = m.group(1) if m else ""
        # Kart uzerindeki gun rozeti basliga yapismis olabilir: "12 Aday Hakem Kursu..."
        if raw_date:
            day = re.match(r"\s*(\d{1,2})", raw_date)
            if day:
                title = re.sub(rf"^\s*0?{int(day.group(1))}\s+(?=\S)", "", title)
        title, tail = split_title(tidy_title(title))
        summary = tail
        if ctx and len(summary) < 80:
            summary = clean(ctx.replace(title.rstrip("…"), " ").replace(raw_date, " "))[:400]
        image = None
        img = a.find("img")
        if img and img.get("src"):
            image = urljoin(base_url, img["src"])
        cat, tags = classify(title, summary, trust_summary=False)
        items.append(Item(title=title, url=full, published_at=parse_tr_date(raw_date),
                          summary=summary[:400], image=image, source_kind="html",
                          raw_date=raw_date, category=cat, tags=tags))
    return items
