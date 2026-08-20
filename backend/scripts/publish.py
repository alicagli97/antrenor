# -*- coding: utf-8 -*-
"""Cakisma-dayanikli yayin adimi.

Sorun: docs/ altindaki dosyalar uretilmis icerik. Saatlik tarama surerken
baska bir gonderim (yerel kopru, elle commit, derin mevzuat kontrolu) araya
girerse `git pull --rebase` meta.json ve index.html uzerinde cakisiyor ve
tur hata ile bitiyor.

Cozum: uretilmis dosyalari birlestirmeye calismak yerine, uzak surumu esas
alip kendi yeni kayitlarimizi onun uzerine ekliyoruz ve turetilmis dosyalari
yeniden uretiyoruz. Duyuru kayitlari kimlikleriyle tekillestigi icin bu islem
guvenli ve tekrarlanabilir.

Kullanim:  python scripts/publish.py "commit mesaji"
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

BACKEND = pathlib.Path(__file__).resolve().parents[1]
REPO = BACKEND.parent
DOCS = REPO / "docs" / "api" / "v1"
STORE = DOCS / "announcements.json"

# Cakisma halinde uzak surumle birlestirilecek, kimlikli kayit listeleri
BIRLESTIRILECEK = {STORE: "id"}
# Bunlarda bizim surumumuz esas alinir (tam yeniden uretiliyorlar)
BIZIM_SURUM = ("calendars.json", "rules.json")

DENEME = 3


def git(*args: str, check: bool = True) -> str:
    r = subprocess.run(["git", *args], cwd=REPO, capture_output=True,
                       text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()[:300]}")
    return (r.stdout or "").strip()


def calistir(betik: str, *args: str) -> None:
    r = subprocess.run([sys.executable, betik, *args], cwd=BACKEND,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    print((r.stdout or r.stderr).strip()[-400:])


def json_oku(path: pathlib.Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []


def degisiklik_var() -> bool:
    return bool(git("status", "--porcelain", "docs"))


def yayinla(mesaj: str) -> int:
    if not degisiklik_var():
        print("degisiklik yok, gonderim atlaniyor")
        return 0

    for deneme in range(1, DENEME + 1):
        git("add", "docs")
        if git("status", "--porcelain", "docs"):
            git("commit", "-m", mesaj)

        try:
            git("push", "origin", "HEAD:main")
            print(f"gonderildi ({deneme}. deneme)")
            return 0
        except RuntimeError as exc:
            print(f"gonderim reddedildi: {str(exc)[:160]}")

        # Uzak surum ilerlemis: kendi yeni kayitlarimizi saklayip uzagi esas al
        bizim = {yol: json_oku(yol) for yol in BIRLESTIRILECEK}
        bizim_ekstra = {ad: (DOCS / ad).read_text(encoding="utf-8")
                        for ad in BIZIM_SURUM if (DOCS / ad).exists()}

        git("fetch", "origin")
        git("reset", "--hard", "origin/main")

        for yol, anahtar in BIRLESTIRILECEK.items():
            uzak = json_oku(yol)
            uzak_idler = {r[anahtar] for r in uzak if isinstance(r, dict) and anahtar in r}
            eklenen = [r for r in bizim.get(yol, [])
                       if isinstance(r, dict) and r.get(anahtar) not in uzak_idler]
            if eklenen:
                birlesik = sorted(eklenen + uzak,
                                  key=lambda r: r.get("published_at") or r.get("first_seen_at") or "",
                                  reverse=True)
                yol.write_text(json.dumps(birlesik, ensure_ascii=False, indent=1),
                               encoding="utf-8")
                print(f"{yol.name}: uzaga {len(eklenen)} yeni kayit eklendi")

        for ad, icerik in bizim_ekstra.items():
            (DOCS / ad).write_text(icerik, encoding="utf-8")

        calistir("scripts/ci_update.py", "--rebuild")
        calistir("scripts/build_site.py")

    print("gonderilemedi: sonraki tur tekrar deneyecek")
    return 1


if __name__ == "__main__":
    mesaj = sys.argv[1] if len(sys.argv) > 1 else "veri guncellemesi"
    raise SystemExit(yayinla(mesaj))
