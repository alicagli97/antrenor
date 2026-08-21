# -*- coding: utf-8 -*-
"""Antrenör logosunu magaza cozunurluklerinde uretir.

Kaynak logo (a1.png) 343x358 piksel. App Store 1024x1024, Play Store 512x512
istiyor; dogrudan buyutmek bulaniklastirir.

Yontem: amblem duz renkli uc yuzeyden olusuyor. Yuzeylerin kose noktalari
kaynak goruntuden olculdu ve poligon olarak taniмlandi; her boyut bu
poligonlardan 4x asiri orneklemeyle ciziliyor. Boylece kenarlar her
cozunurlukte duz ve keskin.

Model kaynakla piksel bazinda karsilastirildi: genel ortusme %97.9
(zemin %99.7, acik yuzey %95.7, orta yuzey %94.1). `--dogrula` ile
yeniden olculebilir.

Yazi (ANTRENÖR) vektorlestirilmedi; kaynaktan yuksek kaliteli olcekleniyor.

Uretilenler (brand/):
    icon-1024.png                 App Store
    icon-512.png                  Play Store
    icon-192.png                  web/PWA
    adaptive-foreground.png       Android uyarlanabilir simge on plani
    adaptive-background.png       Android uyarlanabilir simge zemini
    logo-full-1024.png            amblem + ANTRENÖR (splash / tanitim)
    feature-graphic-1024x500.png  Play Store one cikan gorsel
"""
from __future__ import annotations

import pathlib
import sys
from typing import List, Tuple

from PIL import Image, ImageDraw, ImageFilter

BURASI = pathlib.Path(__file__).resolve().parent
KAYNAK = BURASI.parent / "a1.png"

ZEMIN = (0, 2, 5)

# Amblem yuzeyleri: kose noktalari a1.png uzerinden olculdu (kaynak 343x358).
# Cizim sirasi arkadan one: once tum siluet acik gri, sonra sol kol, sonra kivrim.
SILUET = [(171, 87), (223, 157), (223, 201), (221, 199), (171, 135),
          (121, 199), (119, 201), (119, 157)]
SOL_KOL = [(148, 116), (119, 157), (119, 201), (121, 199), (171, 135), (166, 131)]
KIVRIM = [(148, 116), (153, 112), (171, 132), (166, 137)]

YUZEYLER: List[Tuple[List[Tuple[int, int]], Tuple[int, int, int]]] = [
    (SILUET, (0xC6, 0xC6, 0xC6)),
    (SOL_KOL, (0x7D, 0x7D, 0x7D)),
    (KIVRIM, (0x57, 0x57, 0x57)),
]
YAZI_RENK = (0xF3, 0xF3, 0xF3)

AMBLEM_KUTU = (117, 85, 226, 204)      # amblemin kaynak goruntudeki siniri
YAZI_KUTU = (85, 216, 256, 258)        # ANTRENÖR yazisinin siniri


def maske(im: Image.Image, hedef: Tuple[int, int, int], tolerans: int = 26,
          kutu: Tuple[int, int, int, int] | None = None) -> Image.Image:
    """Renge yakin pikselleri gri tonlu maskeye cevirir."""
    px = im.load()
    x0, y0, x1, y1 = kutu or (0, 0, *im.size)
    m = Image.new("L", (x1 - x0, y1 - y0), 0)
    mp = m.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            p = px[x, y]
            fark = max(abs(p[i] - hedef[i]) for i in range(3))
            if fark <= tolerans:
                mp[x - x0, y - y0] = 255
    return m


def keskin_buyut(m: Image.Image, olcek: float) -> Image.Image:
    """Maskeyi buyutur ve kenari yeniden keskinlestirir.

    Once hafif bulaniklastirip (uzaklik alani benzeri yumusak gecis) buyutur,
    sonra %50 esikle geri keskinlestiririz: duz kenarlar merdiven basamagi
    birakmadan duzlesir.
    """
    # Once kaynagi bicubic ile 4 katina cikarip yumusatiyoruz: dusuk
    # cozunurlukteki merdiven basamaklari boylece duz kenara donusuyor.
    ara = m.resize((m.width * 4, m.height * 4), Image.BICUBIC)
    ara = ara.filter(ImageFilter.GaussianBlur(3.2))
    yeni = (max(1, int(m.width * olcek)), max(1, int(m.height * olcek)))
    buyuk = ara.resize(yeni, Image.BICUBIC)
    # Esik cevresinde dar bir gecis: kenar yumusatma korunur, dalgalanma gider
    return buyuk.point(lambda v: 0 if v < 120 else (255 if v > 136 else int((v - 120) * 255 / 16)))


def amblem(boyut: int, dolgu: float = 0.72, seffaf: bool = False,
           zemin: Tuple[int, int, int] = ZEMIN) -> Image.Image:
    """Amblemi (yazisiz) kare tuvale ortalar. 4x asiri ornekleme ile cizilir."""
    kat = 4
    buyuk = boyut * kat
    x0, y0, x1, y1 = AMBLEM_KUTU
    olcek = (buyuk * dolgu) / max(x1 - x0, y1 - y0)
    kx = (buyuk - (x1 - x0) * olcek) / 2 - x0 * olcek
    ky = (buyuk - (y1 - y0) * olcek) / 2 - y0 * olcek

    tuval = Image.new("RGBA", (buyuk, buyuk), (0, 0, 0, 0) if seffaf else zemin + (255,))
    kalem = ImageDraw.Draw(tuval)
    for noktalar, renk in YUZEYLER:
        kalem.polygon([(x * olcek + kx, y * olcek + ky) for x, y in noktalar],
                      fill=renk + (255,))
    kucuk = tuval.resize((boyut, boyut), Image.LANCZOS)
    return kucuk if seffaf else kucuk.convert("RGB")


def dogrula() -> None:
    """Modeli kaynakla piksel bazinda karsilastirir."""
    from collections import Counter
    kaynak = Image.open(KAYNAK).convert("RGB")
    yeni = Image.new("RGB", kaynak.size, ZEMIN)
    kalem = ImageDraw.Draw(yeni)
    for noktalar, renk in YUZEYLER:
        kalem.polygon(noktalar, fill=renk)

    def sinif(p):
        if sum(p) < 90:
            return "zemin"
        for ad, hedef in (("acik", (0xC6,) * 3), ("orta", (0x7D,) * 3), ("koyu", (0x57,) * 3)):
            if max(abs(p[i] - hedef[i]) for i in range(3)) <= 26:
                return ad
        return "ara"

    k, y = kaynak.load(), yeni.load()
    esles, toplam = Counter(), Counter()
    for j in range(80, 210):
        for i in range(110, 235):
            a, b = sinif(k[i, j]), sinif(y[i, j])
            if a == "ara":
                continue
            toplam[a] += 1
            if a == b:
                esles[a] += 1
    for ad in ("acik", "orta", "koyu", "zemin"):
        if toplam[ad]:
            print(f"  {ad:6}: %{100 * esles[ad] / toplam[ad]:.1f}")
    print(f"  genel : %{100 * sum(esles.values()) / sum(toplam.values()):.1f}")


def yazi(genislik: int) -> Image.Image:
    """ANTRENÖR yazisini seffaf zeminde uretir.

    Yazi vektorlestirilmedi: harf bicimi ozgun logoya ait ve elimizde yazi
    tipi yok (Windows'taki adaylarla en iyi eslesme %43'te kaldi, yani baska
    bir font kullanmak kimligi degistirirdi). Bu yuzden kaynaktaki yazi
    yuksek kaliteli olcekleniyor; 171 px genislikteki kaynak buyudukce
    yumusuyor. Basim kalitesi gerekirse ozgun logo dosyasi gerekir.
    """
    kaynak = Image.open(KAYNAK).convert("RGB")
    x0, y0, x1, y1 = YAZI_KUTU
    olcek = genislik / (x1 - x0)
    m = maske(kaynak, YAZI_RENK, tolerans=60, kutu=YAZI_KUTU)
    buyuk = m.resize((genislik, max(1, int(m.height * olcek))), Image.LANCZOS)
    buyuk = buyuk.filter(ImageFilter.UnsharpMask(radius=olcek * 0.6, percent=140, threshold=2))
    katman = Image.new("RGBA", buyuk.size, YAZI_RENK + (255,))
    katman.putalpha(buyuk)
    return katman


def kilit(boyut: int) -> Image.Image:
    """Amblem + yazi: splash ve tanitim gorselleri icin."""
    tuval = Image.new("RGB", (boyut, boyut), ZEMIN)
    a = amblem(int(boyut * 0.52), dolgu=0.92, seffaf=True)
    tuval.paste(a, ((boyut - a.width) // 2, int(boyut * 0.18)), a)
    y = yazi(int(boyut * 0.54))
    tuval.paste(y, ((boyut - y.width) // 2, int(boyut * 0.70)), y)
    return tuval


def main() -> None:
    BURASI.mkdir(exist_ok=True)
    if "--dogrula" in sys.argv:
        dogrula()
        return

    for boyut, ad in ((1024, "icon-1024.png"), (512, "icon-512.png"), (192, "icon-192.png")):
        amblem(boyut).save(BURASI / ad)
        print("yazildi:", ad)

    # Android uyarlanabilir simge: gorsel guvenli alanda kalmali
    amblem(432, dolgu=0.58, seffaf=True).save(BURASI / "adaptive-foreground.png")
    Image.new("RGB", (432, 432), ZEMIN).save(BURASI / "adaptive-background.png")
    print("yazildi: adaptive-foreground.png + adaptive-background.png")

    for boyut in (1024, 2048):
        kilit(boyut).save(BURASI / f"logo-full-{boyut}.png")
        print(f"yazildi: logo-full-{boyut}.png")

    one_cikan = Image.new("RGB", (1024, 500), ZEMIN)
    a = amblem(300, dolgu=0.92, seffaf=True)
    one_cikan.paste(a, (110, 100), a)
    y = yazi(400)
    one_cikan.paste(y, (450, 250 - y.height // 2), y)
    one_cikan.save(BURASI / "feature-graphic-1024x500.png")
    print("yazildi: feature-graphic-1024x500.png")


if __name__ == "__main__":
    main()
