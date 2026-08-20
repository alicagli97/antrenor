# -*- coding: utf-8 -*-
"""Yerel kopru: GitHub sunucusundan erisilemeyen kaynaklari bu bilgisayardan besler.

Neden gerekli
-------------
Basketbol Federasyonu (tbf.org.tr) Cloudflare bot dogrulamasi kullaniyor.
Dogrulama ev/ofis baglantisindan gecerken GitHub Actions'in veri merkezi
IP'sinden gecmiyor. Bu betik yalnizca o kaynaklari tarar, sonucu ayni
depoya isler ve gonderir. Bilgisayar kapaliyken diger 63 kaynak GitHub'da
taranmaya devam eder; kopru acildiginda eksikler tamamlanir.

Kullanim
--------
    python scripts/local_bridge.py            # bir kez calistir
    python scripts/local_bridge.py --watch    # 6 saatte bir tekrarla
"""
from __future__ import annotations

import asyncio
import os
import pathlib
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]

# GitHub'dan erisilemeyen, yerel baglantidan calisan kaynaklar
KOPRU_SLUGS = ["basketbol"]

WATCH_INTERVAL_HOURS = 6
MAX_PUSH_RETRY = 3


def git(*args: str, check: bool = True) -> str:
    result = subprocess.run(["git", *args], cwd=REPO, capture_output=True,
                            text=True, encoding="utf-8", errors="replace")
    if check and result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} -> {result.stderr.strip()[:300]}")
    return (result.stdout or "").strip()


def calistir_tarama() -> int:
    """ci_update.py'yi yalnizca kopru kaynaklari icin calistirir."""
    env = dict(os.environ, PYTHONIOENCODING="utf-8", ONLY_SLUGS=",".join(KOPRU_SLUGS))
    result = subprocess.run([sys.executable, str(HERE / "ci_update.py")],
                            cwd=HERE.parent, env=env, capture_output=True,
                            text=True, encoding="utf-8", errors="replace")
    print(result.stdout.strip() or result.stderr.strip()[:500])
    return result.returncode


def tur() -> None:
    print(f"\n=== kopru turu: {time.strftime('%Y-%m-%d %H:%M')}")

    # Once GitHub'daki son durumu al, yoksa cakisma cikar
    git("fetch", "--quiet", "origin")
    git("pull", "--rebase", "--autostash", "--quiet", "origin", "main", check=False)

    if calistir_tarama() != 0:
        print("tarama basarisiz, bu tur atlaniyor")
        return

    if not git("status", "--porcelain", "docs"):
        print("degisiklik yok")
        return

    # Gonderimi cakisma-dayanikli yayin betigi yapar
    sonuc = subprocess.run([sys.executable, str(HERE / "publish.py"),
                            f"yerel kopru: {', '.join(KOPRU_SLUGS)}"],
                           cwd=HERE.parent, text=True, encoding="utf-8", errors="replace")
    if sonuc.returncode != 0:
        print("gonderilemedi, sonraki turda tekrar denenecek")


def main() -> None:
    watch = "--watch" in sys.argv
    while True:
        try:
            tur()
        except Exception as exc:
            print(f"hata: {type(exc).__name__}: {exc}")
        if not watch:
            return
        print(f"sonraki tur {WATCH_INTERVAL_HOURS} saat sonra")
        time.sleep(WATCH_INTERVAL_HOURS * 3600)


if __name__ == "__main__":
    main()
