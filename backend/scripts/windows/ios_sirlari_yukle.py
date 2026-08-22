# -*- coding: utf-8 -*-
"""Apple'dan indirilen imzalama dosyalarini isleyip GitHub sirlarina yazar.

Apple portalindaki adimlar (giris + iki adimli dogrulama gerektirdigi icin
elle yapiliyor) bittikten sonra bu betik geri kalan her seyi ustleniyor:

    1. .cer  -> ozel anahtarla birlestirip .p12 uretir
    2. .p12 ve .mobileprovision dosyalarini base64'e cevirir
    3. App Store Connect API anahtarini (.p8) okur
    4. Hepsini `gh secret set` ile depoya yazar

Kullanim:
    python backend/scripts/windows/ios_sirlari_yukle.py

Dosyalarin bulunmasi gereken klasor (adlari onemli degil, uzantilari yeterli):
    C:\\Users\\PEGASUS\\AntrenorAnahtar\\ios\\
        dagitim.key                 (bu betikten once uretildi)
        *.cer                       Apple Distribution sertifikasi
        *.mobileprovision           App Store profili
        AuthKey_XXXXXXXXXX.p8       App Store Connect API anahtari
"""
from __future__ import annotations

import base64
import pathlib
import re
import secrets
import string
import subprocess
import sys

DIZIN = pathlib.Path(r"C:\Users\PEGASUS\AntrenorAnahtar\ios")
DEPO = "alicagli97/antrenor"


def tek_dosya(desen: str) -> pathlib.Path | None:
    bulunan = sorted(DIZIN.glob(desen))
    if not bulunan:
        return None
    if len(bulunan) > 1:
        print(f"  uyari: birden fazla {desen} var, en yenisi kullanildi")
        bulunan.sort(key=lambda p: p.stat().st_mtime)
    return bulunan[-1]


def calistir(*args: str, girdi: bytes | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(args, input=girdi, capture_output=True)


def p12_uret(cer: pathlib.Path, anahtar: pathlib.Path, sifre: str) -> pathlib.Path | None:
    """Apple .cer dosyasini DER olarak veriyor; PEM'e cevirip anahtarla birlestiriyoruz."""
    pem = DIZIN / "dagitim.pem"
    p12 = DIZIN / "dagitim.p12"

    sonuc = calistir("openssl", "x509", "-inform", "DER", "-in", str(cer),
                     "-out", str(pem))
    if sonuc.returncode != 0:
        # Bazi tarayicilar sertifikayi PEM olarak indiriyor
        sonuc = calistir("openssl", "x509", "-inform", "PEM", "-in", str(cer),
                         "-out", str(pem))
    if sonuc.returncode != 0:
        print("  HATA: sertifika okunamadi ->",
              sonuc.stderr.decode("utf-8", "replace")[:200])
        return None

    sonuc = calistir("openssl", "pkcs12", "-export",
                     "-inkey", str(anahtar), "-in", str(pem),
                     "-out", str(p12), "-passout", f"pass:{sifre}",
                     "-legacy")
    if sonuc.returncode != 0:
        sonuc = calistir("openssl", "pkcs12", "-export",
                         "-inkey", str(anahtar), "-in", str(pem),
                         "-out", str(p12), "-passout", f"pass:{sifre}")
    if sonuc.returncode != 0:
        print("  HATA: p12 uretilemedi ->",
              sonuc.stderr.decode("utf-8", "replace")[:200])
        return None
    pem.unlink(missing_ok=True)
    return p12


def sir_yaz(ad: str, deger: str) -> bool:
    sonuc = subprocess.run(["gh", "secret", "set", ad, "--repo", DEPO],
                           input=deger.encode("utf-8"), capture_output=True)
    ok = sonuc.returncode == 0
    print(f"  {'✓' if ok else '✗'} {ad}"
          + ("" if ok else f"  ({sonuc.stderr.decode('utf-8', 'replace')[:120]})"))
    return ok


def main() -> int:
    print(f"klasor: {DIZIN}\n")

    anahtar = DIZIN / "dagitim.key"
    cer = tek_dosya("*.cer")
    profil = tek_dosya("*.mobileprovision")
    p8 = tek_dosya("*.p8")

    eksik = []
    if not anahtar.exists():
        eksik.append("dagitim.key (CSR ile birlikte uretilmisti)")
    if not cer:
        eksik.append(".cer  — Apple Distribution sertifikasi")
    if not profil:
        eksik.append(".mobileprovision  — App Store profili")
    if not p8:
        eksik.append(".p8  — App Store Connect API anahtari")
    if eksik:
        print("Eksik dosyalar:")
        for e in eksik:
            print("  -", e)
        print("\nBunlari Apple portalindan indirip yukaridaki klasore koyun.")
        return 1

    sifre = "".join(secrets.choice(string.ascii_letters + string.digits)
                    for _ in range(24))
    print("sertifika paketi uretiliyor...")
    p12 = p12_uret(cer, anahtar, sifre)
    if not p12:
        return 1
    print(f"  ✓ {p12.name}\n")

    # Anahtar kimligi dosya adinda: AuthKey_ABC1234XYZ.p8
    eslesme = re.search(r"AuthKey_([A-Z0-9]{10})", p8.name)
    anahtar_kimligi = eslesme.group(1) if eslesme else ""
    if not anahtar_kimligi:
        print(f"  uyari: {p8.name} adindan Key ID okunamadi, elle girilmeli")

    print("GitHub sirlari yaziliyor...")
    tamam = True
    tamam &= sir_yaz("IOS_SERTIFIKA_P12",
                     base64.b64encode(p12.read_bytes()).decode())
    tamam &= sir_yaz("IOS_SERTIFIKA_SIFRE", sifre)
    tamam &= sir_yaz("IOS_PROVISION_PROFILE",
                     base64.b64encode(profil.read_bytes()).decode())
    tamam &= sir_yaz("APPSTORE_KEY_P8", p8.read_text(encoding="utf-8"))
    if anahtar_kimligi:
        tamam &= sir_yaz("APPSTORE_KEY_ID", anahtar_kimligi)

    print()
    if not anahtar_kimligi:
        print("Elle eklenmesi gereken: APPSTORE_KEY_ID")
    print("Elle eklenmesi gereken: APPSTORE_ISSUER_ID "
          "(App Store Connect > Integrations > App Store Connect API sayfasinda)")
    print("  gh secret set APPSTORE_ISSUER_ID --repo " + DEPO)
    print()
    print("Hazir olunca:  gh workflow run iOS -f kip=yukle")
    return 0 if tamam else 1


if __name__ == "__main__":
    raise SystemExit(main())
