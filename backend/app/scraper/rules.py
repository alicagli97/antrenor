# -*- coding: utf-8 -*-
"""Yarisma kurallari / mevzuat kutuphanesi.

Federasyonlar yarisma talimatlarini, oyun kurallarini, ana statuyu ve
yonergeleri sitelerinde yayinlar. Antrenor icin bunlar duyuru kadar
baglayicidir: "Antrenor Egitim Talimati" degistiginde kademe sartlari,
"Musabaka Talimati" degistiginde yarisma kurallari degisir.

Bu modul:
  1. Federasyon sitesinde mevzuat/talimat sayfasini bulur.
  2. O sayfadaki belgeleri (PDF/Word/HTML) baslikariyla listeler.
  3. Liste ve belge parmak izlerini saklar; yeni veya guncellenen
     talimat oldugunda haber verir.

Not: calendars.py ile ortak yardimcilar (belge_turu, parmak_izi, pdf_metni)
oradan alinir; iki kutuphane ayni temeli paylasir.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from .calendars import belge_turu, parmak_izi, pdf_metni
from .extract import _lower_tr, clean
from .http_client import get

# Mevzuat sayfasina goturen baglanti metinleri
MEVZUAT_SOZCUKLERI = (
    "mevzuat", "talimat", "talimatlar", "yönetmelik", "yonetmelik", "yönerge",
    "yonerge", "ana statü", "ana statu", "kurallar", "oyun kuralları",
    "oyun kurallari", "yarışma kuralları", "yarisma kurallari",
    "müsabaka talimatı", "musabaka talimati", "kural kitabı", "kural kitabi",
    "genelge", "regulations", "rules",
)

# Belge basligi bunlardan birini iceriyorsa kural belgesi sayilir
BELGE_SOZCUKLERI = (
    "talimat", "yönetmelik", "yonetmelik", "yönerge", "yonerge", "statü", "statu",
    "kural", "genelge", "esaslar", "prensip", "kılavuz", "kilavuz", "rehber",
    "protokol", "regulation", "rules",
)

# Bunlar mevzuat degil
MEVZUAT_DISI = ("faaliyet takvimi", "faaliyet programı", "başvuru formu",
                "basvuru formu", "sonuç", "sonuc", "fikstür", "fikstur",
                "katılımcı listesi", "katilimci listesi", "banka", "iban")

# Antrenoru dogrudan ilgilendiren belgeler one cikarilir
ONCELIKLI = ("antrenör", "antrenor", "hakem", "kademe", "vize", "eğitim", "egitim",
             "lisans", "tescil", "kulüp", "kulup", "sporcu")


@dataclass
class KuralBelgesi:
    baslik: str
    url: str
    tur: str                       # pdf | word | excel | html
    onemli: bool = False           # antrenoru dogrudan ilgilendiriyor mu
    parmak_izi: str = ""           # icerik degisimini yakalamak icin
    guncellendi: Optional[str] = None


@dataclass
class KuralKaynagi:
    url: str
    label: str = ""
    belge_sayisi: int = 0
    score: float = 0.0
    belgeler: List[KuralBelgesi] = field(default_factory=list)


def mevzuat_baglantisi_mi(text: str, href: str) -> bool:
    blob = _lower_tr(f"{text} {href}")
    if any(k in blob for k in MEVZUAT_DISI):
        return False
    return any(k in blob for k in MEVZUAT_SOZCUKLERI)


def kural_belgesi_mi(baslik: str, url: str) -> bool:
    blob = _lower_tr(f"{baslik} {url}")
    if any(k in blob for k in MEVZUAT_DISI):
        return False
    return any(k in blob for k in BELGE_SOZCUKLERI)


def aday_sayfalar(base_url: str, html: str) -> List[tuple[str, str]]:
    """Ana sayfadan mevzuat/talimat sayfasina giden baglantilar."""
    soup = BeautifulSoup(html or "", "lxml")
    host = urlparse(base_url).netloc.replace("www.", "")
    bulunan: List[tuple[str, str]] = []
    for a in soup.find_all("a", href=True):
        metin = clean(a.get_text(" "))
        if not mevzuat_baglantisi_mi(metin, a["href"]):
            continue
        tam = urljoin(base_url, a["href"])
        if tam.startswith(("mailto:", "javascript:")):
            continue
        hedef = urlparse(tam).netloc.replace("www.", "")
        if hedef and hedef != host and not belge_turu(tam) and not hedef.endswith("." + host):
            continue
        bulunan.append((tam, metin[:90] or "mevzuat"))

    gorulen, sonuc = set(), []
    for url, etiket in bulunan:
        if url.rstrip("/") in gorulen:
            continue
        gorulen.add(url.rstrip("/"))
        sonuc.append((url, etiket))
    return sonuc[:10]


def sayfadaki_belgeler(base_url: str, html: str) -> List[KuralBelgesi]:
    """Mevzuat sayfasindaki kural belgelerini baslikariyla toplar."""
    soup = BeautifulSoup(html, "lxml")
    for bad in soup.find_all(["nav", "header", "footer", "script", "style"]):
        bad.decompose()

    belgeler: List[KuralBelgesi] = []
    gorulen = set()
    for a in soup.find_all("a", href=True):
        baslik = clean(a.get_text(" "))
        tam = urljoin(base_url, a["href"])
        if tam.rstrip("/") in gorulen or tam.startswith(("mailto:", "javascript:")):
            continue
        tur = belge_turu(tam)

        # Baslik bostaysa dosya adindan uret
        if not baslik and tur:
            baslik = urlparse(tam).path.rstrip("/").rsplit("/", 1)[-1]
            baslik = re.sub(r"[-_]+", " ", baslik.rsplit(".", 1)[0])[:120]
        if len(baslik) < 8:
            continue
        if not kural_belgesi_mi(baslik, tam):
            continue

        gorulen.add(tam.rstrip("/"))
        blob = _lower_tr(baslik)
        belgeler.append(KuralBelgesi(
            baslik=baslik[:220], url=tam[:500], tur=tur or "html",
            onemli=any(k in blob for k in ONCELIKLI)))
    return belgeler


def liste_parmak_izi(belgeler: List[KuralBelgesi]) -> str:
    """Belge listesinin kimligi: ekleme/cikarma bu izden anlasilir."""
    imza = "|".join(sorted(f"{b.baslik}::{b.url}" for b in belgeler))
    return parmak_izi(imza)


async def belge_parmak_izi(client, belge: KuralBelgesi) -> str:
    """Belgenin icerik izi: ayni adreste sessizce guncellenen PDF'leri yakalar."""
    r = await get(client, belge.url, retries=1)
    if not r:
        return ""
    if belge.tur == "pdf":
        metin = pdf_metni(r.content, sayfa_siniri=6)
        if metin:
            return parmak_izi(metin)
    return parmak_izi(r.content)


def onemli_siralama(belgeler: List[KuralBelgesi]) -> List[KuralBelgesi]:
    """Antrenoru ilgilendiren belgeler basa alinir."""
    return sorted(belgeler, key=lambda b: (not b.onemli, _lower_tr(b.baslik)))
