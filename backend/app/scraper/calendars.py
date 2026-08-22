# -*- coding: utf-8 -*-
"""Faaliyet takvimi kesfi, cekimi ve degisiklik takibi.

Her federasyon yil basinda bir faaliyet programi yayinlar; yil icinde
degisir (tarih kayar, yarisma eklenir/iptal olur). Antrenor icin bu degisiklik
duyuru kadar onemli. Bu modul:

  1. Federasyon sitesinde takvim kaynagini bulur (HTML sayfa, PDF, Excel).
  2. Icerigi ceker; HTML tablolarindan etkinlikleri satir satir cikarir.
  3. Icerik parmak izini saklar; degisince "takvim guncellendi" bildirir.

Belge (PDF/Excel) olan kaynaklarda satir cikarimi yapilmaz; belgenin
degisip degismedigi izlenir ve kullaniciya dogrudan belge baglantisi verilir.
"""
from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from .dates import parse_tr_date
from .extract import clean, _lower_tr
from .http_client import get

# pypdf bozuk PDF'lerde her nesne icin uyari basiyor; gunlugu bogmasin
logging.getLogger("pypdf").setLevel(logging.ERROR)

# Takvim sayfasi/belgesi olma ihtimali olan baglanti metinleri
TAKVIM_SOZCUKLERI = (
    "faaliyet programı", "faaliyet programi", "faaliyet takvimi", "faaliyet tak",
    "yarışma takvimi", "yarisma takvimi", "müsabaka takvimi", "musabaka takvimi",
    "etkinlik takvimi", "sezon programı", "yıllık program", "yillik program",
    "yarışma programı", "yarisma programi", "müsabaka programı", "musabaka programi",
    "organizasyonlar", "fikstür", "fikstur",
    "faaliyet", "takvim", "activity calendar", "fixture",
)

# Bunlar takvim degil: yanlis eslesmeleri ayikla.
# Federasyon sitelerinde "faaliyet" kelimesi KVKK formundan yillik rapora,
# logo dosyasindan basvuru formuna kadar cok yerde geciyor.
TAKVIM_DISI = (
    "faaliyet raporu", "faaliyet belgesi", "denetim raporu", "faaliyet alanları",
    "takvimi geçmiş", "arşiv takvim", "kvkk", "kişisel veri", "kisisel veri",
    "aydınlatma", "aydinlatma", "başvuru formu", "basvuru formu", "logo",
    "yönetmelik", "yonetmelik", "talimat", "ana statü", "ana statu", "sözleşme",
    "sozlesme", "genelge", "sonuçları", "sonuclari", "katılımcı listesi",
    "bütçe", "butce", "mali rapor",
)

# Icerikte gecerse kesinlikle takvim degildir. Baglanti suzgecinden (TAKVIM_DISI)
# ayri tutuluyor: "talimat", "yonetmelik" gibi kelimeler sayfa menusunde de
# gectigi icin gecerli takvim sayfalarini eliyordu.
ICERIK_DISI = ("kişisel veri", "kisisel veri", "kvkk", "aydınlatma metni",
               "aydinlatma metni", "başvuru formu", "basvuru formu",
               "faaliyet raporu", "denetim raporu")

# Baglanti metninde/adresinde bunlar varsa takvim olma ihtimali yuksek
GUCLU_ISARETLER = ("faaliyet programı", "faaliyet programi", "faaliyet takvimi",
                   "yarışma takvimi", "yarisma takvimi", "müsabaka takvimi",
                   "musabaka takvimi", "yarışma programı", "yarisma programi",
                   "müsabaka programı", "musabaka programi", "sezon programı",
                   "faaliyet-takvim", "faaliyet_takvim", "faaliyet-programi",
                   "takvim", "fikstür", "fikstur")

BELGE_UZANTILARI = {".pdf": "pdf", ".xls": "excel", ".xlsx": "excel",
                    ".doc": "word", ".docx": "word"}

# Tablo basliklarinda arayacagimiz alanlar
BASLIK_ESLESME = {
    "ad": ("faaliyet", "yarışma", "yarisma", "müsabaka", "musabaka", "organizasyon",
           "etkinlik", "açıklama", "aciklama", "adı", "adi", "konu"),
    "tarih": ("tarih", "başlangıç", "baslangic", "bitiş", "bitis", "date"),
    "yer": ("yer", "il", "şehir", "sehir", "mekan", "lokasyon", "yeri"),
    "brans": ("branş", "brans", "kategori", "tür", "tur", "sınıf"),
}


@dataclass
class TakvimKaynagi:
    url: str
    tur: str                     # html | pdf | excel | word
    label: str = ""
    score: float = 0.0
    event_count: int = 0


@dataclass
class Etkinlik:
    ad: str
    tarih: Optional[str] = None          # ISO gun
    tarih_metni: str = ""                # kaynaktaki ham metin
    yer: str = ""
    brans: str = ""
    satir: str = ""                      # tam satir metni (arama icin)


@dataclass
class TakvimDurumu:
    federation: str
    url: str
    tur: str
    parmak_izi: str
    etkinlikler: List[Etkinlik] = field(default_factory=list)
    kontrol_edildi: str = ""
    degisti_mi: bool = False


_YIL = re.compile(r"20\d{2}")


def yil_puani(metin: str, bugun: Optional[datetime] = None) -> float:
    """Takvim adayini yila gore puanlar.

    Federasyon siteleri eski yillarin takvimlerini de yayinda tutuyor;
    2018 faaliyet programi ile 2026 programi ayni menude durabiliyor.
    Guncel sezonu iceren baglanti one cikarilir, eskiler geri itilir.
    """
    bugun = bugun or datetime.utcnow()
    yillar = [int(y) for y in _YIL.findall(metin)]
    if not yillar:
        return 0.0
    encok = max(yillar)
    fark = encok - bugun.year
    if fark >= 0:                 # bu yil veya gelecek sezon
        return 45.0
    if fark == -1:                # gecen yil: sezon devam ediyor olabilir
        return 5.0
    return -40.0                  # daha eski: neredeyse kesin arsiv


def belge_turu(url: str) -> Optional[str]:
    yol = urlparse(url).path.lower()
    for uzanti, tur in BELGE_UZANTILARI.items():
        if yol.endswith(uzanti):
            return tur
    return None


def takvim_baglantisi_mi(text: str, href: str) -> bool:
    blob = _lower_tr(f"{text} {href}")
    if any(k in blob for k in TAKVIM_DISI):
        return False
    return any(k in blob for k in TAKVIM_SOZCUKLERI)


def aday_baglantilar(base_url: str, html: str) -> List[tuple[str, str]]:
    """Sayfadaki takvim adayi baglantilar: (url, etiket)."""
    soup = BeautifulSoup(html or "", "lxml")
    host = urlparse(base_url).netloc.replace("www.", "")
    bulunan: List[tuple[str, str]] = []
    for a in soup.find_all("a", href=True):
        metin = clean(a.get_text(" "))
        href = a["href"]
        if not takvim_baglantisi_mi(metin, href):
            continue
        tam = urljoin(base_url, href)
        if tam.startswith("mailto:") or tam.startswith("javascript:"):
            continue
        hedef = urlparse(tam).netloc.replace("www.", "")
        # Belgeler baska bir sunucuda olabilir (drive, cdn); onlara izin ver
        if hedef and hedef != host and not belge_turu(tam) and not hedef.endswith("." + host):
            continue
        bulunan.append((tam, metin[:80] or "takvim"))
    # Tekille, sirayi koru
    gorulen, sonuc = set(), []
    for url, etiket in bulunan:
        anahtar = url.rstrip("/")
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        sonuc.append((url, etiket))
    return sonuc[:12]


# --- HTML tablo cikarimi -----------------------------------------------------

def _sutun_haritasi(basliklar: List[str]) -> Dict[str, int]:
    harita: Dict[str, int] = {}
    for i, baslik in enumerate(basliklar):
        b = _lower_tr(baslik)
        for alan, kelimeler in BASLIK_ESLESME.items():
            if alan in harita:
                continue
            if any(k in b for k in kelimeler):
                harita[alan] = i
    return harita


def tablodan_etkinlikler(html: str) -> List[Etkinlik]:
    """Takvim sayfasindaki tablolardan etkinlik satirlarini cikarir."""
    soup = BeautifulSoup(html, "lxml")
    etkinlikler: List[Etkinlik] = []

    for tablo in soup.find_all("table"):
        satirlar = tablo.find_all("tr")
        if len(satirlar) < 3:
            continue

        basliklar = [clean(h.get_text(" ")) for h in satirlar[0].find_all(["th", "td"])]
        harita = _sutun_haritasi(basliklar)
        if "ad" not in harita and "tarih" not in harita:
            continue

        for satir in satirlar[1:]:
            hucreler = [clean(h.get_text(" ")) for h in satir.find_all(["td", "th"])]
            if len(hucreler) < 2 or not any(hucreler):
                continue
            tam_satir = " | ".join(h for h in hucreler if h)

            def al(alan: str) -> str:
                i = harita.get(alan)
                return hucreler[i] if i is not None and i < len(hucreler) else ""

            ad = al("ad") or max(hucreler, key=len)
            if len(ad) < 6:
                continue
            tarih_metni = al("tarih") or next(
                (h for h in hucreler if re.search(r"\d{1,2}[./-]\d{1,2}", h)), "")
            gun = parse_tr_date(tarih_metni)
            etkinlikler.append(Etkinlik(
                ad=ad[:220], tarih=gun.date().isoformat() if gun else None,
                tarih_metni=tarih_metni[:60], yer=al("yer")[:80],
                brans=al("brans")[:80], satir=tam_satir[:400]))

    return etkinlikler


# --- PDF metni ---------------------------------------------------------------

_TARIH_SATIRI = re.compile(
    r"\d{1,2}\s*[./-]\s*\d{1,2}(\s*[./-]\s*\d{2,4})?"
    r"|\d{1,2}\s+(?:Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)",
    re.IGNORECASE)


def pdf_metni(icerik: bytes, sayfa_siniri: int = 12) -> str:
    """PDF icindeki metni cikarir. pypdf yoksa bos doner."""
    try:
        import io

        from pypdf import PdfReader
    except ImportError:
        return ""
    try:
        okuyucu = PdfReader(io.BytesIO(icerik))
        parcalar = []
        for sayfa in okuyucu.pages[:sayfa_siniri]:
            parcalar.append(sayfa.extract_text() or "")
        return "\n".join(parcalar)
    except Exception:
        return ""


def metinden_etkinlikler(metin: str) -> List[Etkinlik]:
    """Belge metninde tarih iceren satirlari faaliyet olarak alir.

    Federasyon PDF'leri tek bir sablona uymuyor; bu yuzden satiri oldugu gibi
    saklayip yalnizca tarih ve ad alanlarini ayirmaya calisiyoruz. Amac
    kusursuz ayristirma degil, takvimin uygulama icinde aranabilir olmasi.
    """
    etkinlikler: List[Etkinlik] = []
    for ham in metin.splitlines():
        satir = " ".join(ham.split())
        if len(satir) < 12 or len(satir) > 300:
            continue
        m = _TARIH_SATIRI.search(satir)
        if not m:
            continue
        tarih_metni = m.group(0)
        ad = clean(satir.replace(tarih_metni, " ")).strip(" -–|.")
        if len(ad) < 6:
            continue
        gun = parse_tr_date(satir)
        etkinlikler.append(Etkinlik(
            ad=ad[:220], tarih=gun.date().isoformat() if gun else None,
            tarih_metni=tarih_metni[:60], satir=satir[:400]))
    return etkinlikler


# Takvim metninde bulmayi bekledigimiz sozcukler
ICERIK_SOZCUKLERI = ("faaliyet", "yarışma", "yarisma", "müsabaka", "musabaka",
                     "şampiyona", "sampiyona", "turnuva", "kurs", "seminer",
                     "lig", "kupa", "tarih", "takvim", "organizasyon")


def takvim_gibi_mi(metin: str, katı: bool = False) -> bool:
    """Cekilen belge/sayfa gercekten takvim mi?

    Takvim saymak icin hem birden fazla tarih hem de takvim sozcugu ariyoruz.
    Belgelerde (PDF/Excel) esik daha yuksek: bir KVKK formunda da tarih ve
    "faaliyet" kelimesi gecebiliyor, ama alt alta 6+ tarih gecmez.
    """
    if not metin or len(metin) < 120:
        return False
    tarih_sayisi = len(_TARIH_SATIRI.findall(metin))
    alcak = _lower_tr(metin)
    kelime_sayisi = sum(1 for k in ICERIK_SOZCUKLERI if k in alcak)
    if any(k in alcak[:300] for k in ICERIK_DISI):
        return False
    if katı:
        # Yogun tarih izgarasi (ör. "7-8  14-15  21-22" bicimli aylik takvimler)
        # tek basina yeterli kanittir; boyle belgelerde metin cok az kelime icerir.
        if tarih_sayisi >= 15:
            return True
        return tarih_sayisi >= 6 and kelime_sayisi >= 2
    return tarih_sayisi >= 3 and kelime_sayisi >= 1


def eski_mi(etiket: str, url: str = "", bugun: Optional[datetime] = None) -> bool:
    """Etiket ve dosya adindaki yila bakarak arsiv mi karar verir.

    Adresin klasor kismina bakilmaz: WordPress dosyalari /uploads/2025/12/
    altinda dursa da icerik 2026 takvimi olabiliyor. Yil bilgisi icin
    baglanti metni ve dosya adi kullanilir.
    """
    bugun = bugun or datetime.utcnow()
    # Sondaki egik cizgi dosya adini gizlemesin: /2023-faaliyet-takvimi/
    dosya = urlparse(url).path.rstrip("/").rsplit("/", 1)[-1] if url else ""
    yillar = [int(y) for y in _YIL.findall(f"{etiket} {dosya}")]
    return bool(yillar) and max(yillar) < bugun.year


# Federasyon sitelerinde sik kullanilan takvim adresleri
YAYGIN_TAKVIM_YOLLARI = (
    "/faaliyet-takvimi", "/faaliyet-programi", "/faaliyetler", "/takvim",
    "/tr/faaliyetler", "/tr/faaliyet-takvimi", "/yarisma-takvimi",
    "/musabaka-takvimi", "/faaliyet_takvimi.php", "/faaliyet-takvimi/",
    "/etkinlikler", "/organizasyonlar", "/fikstur",
)


def parmak_izi(icerik: bytes | str) -> str:
    veri = icerik.encode("utf-8", "ignore") if isinstance(icerik, str) else icerik
    return hashlib.sha1(veri).hexdigest()[:16]


def html_ozu(html: str) -> str:
    """Parmak izi icin gurultuden arindirilmis metin.

    Ziyaretci sayaci, reklam, tarih damgasi gibi her istekte degisen
    parcalar yuzunden takvim 'degisti' sanilmasin diye once temizlik yapilir.
    """
    soup = BeautifulSoup(html, "lxml")
    for bad in soup.find_all(["script", "style", "nav", "header", "footer", "aside", "form"]):
        bad.decompose()
    govde = soup.find("table") or soup.find("main") or soup.body or soup
    metin = clean(govde.get_text(" "))
    metin = re.sub(r"\d{1,2}:\d{2}(:\d{2})?", "", metin)          # saat damgalari
    return metin


# Bazi siteler olmayan sayfayi 404 yerine 200 ile "hata sayfasina" yonlendiriyor.
# Adres bunu ele veriyor; yoksa kullaniciya takvim diye bozuk baglanti gosteriyoruz.
HATA_ADRESI = re.compile(
    r"(error=|/404\b|404\.|not[-+%20 ]?found|sayfa[-_]?bulunamadi|page[-_]not[-_]found)",
    re.I)


def hata_sayfasi_mi(url: str) -> bool:
    return bool(HATA_ADRESI.search(url or ""))


async def kaynak_cek(client, kaynak: TakvimKaynagi) -> Optional[TakvimDurumu]:
    """Takvim kaynagini ceker, parmak izi ve (varsa) etkinlik listesi uretir."""
    r = await get(client, kaynak.url)
    if not r:
        return None

    # Yonlendirme sonrasi adres hata sayfasini gosteriyorsa takvim degildir
    if hata_sayfasi_mi(str(r.url)):
        return None

    if kaynak.tur == "html":
        oz = html_ozu(r.text)
        if len(oz) < 80 or not takvim_gibi_mi(oz):
            return None
        return TakvimDurumu(federation="", url=str(r.url), tur="html",
                            parmak_izi=parmak_izi(oz),
                            etkinlikler=tablodan_etkinlikler(r.text),
                            kontrol_edildi=datetime.utcnow().isoformat(timespec="seconds"))

    # Belge: icerigin kendisinden parmak izi al (ETag her sunucuda guvenilir degil)
    etkinlikler: List[Etkinlik] = []
    if kaynak.tur == "pdf":
        metin = pdf_metni(r.content)
        # Taranmis veya gorsel tabloli PDF'lerde pypdf cok az metin cikarir;
        # boyle belgeleri reddetmek yerine (baglanti zaten "takvim" diyor)
        # izlemeye alip degisikligi takip ediyoruz.
        if len(metin) >= 400:
            if not takvim_gibi_mi(metin, katı=True):
                return None
            etkinlikler = metinden_etkinlikler(metin)
    return TakvimDurumu(federation="", url=str(r.url), tur=kaynak.tur,
                        parmak_izi=parmak_izi(r.content),
                        etkinlikler=etkinlikler,
                        kontrol_edildi=datetime.utcnow().isoformat(timespec="seconds"))
