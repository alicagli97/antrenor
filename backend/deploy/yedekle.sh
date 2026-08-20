#!/usr/bin/env bash
# Gunluk veritabani yedegi (cron: 0 4 * * *  /opt/antrenor/backend/deploy/yedekle.sh)
set -euo pipefail

HEDEF="${YEDEK_DIZINI:-/var/backups/antrenor}"
GUN=$(date +%Y%m%d)
mkdir -p "$HEDEF"

if command -v docker >/dev/null && docker compose ps db >/dev/null 2>&1; then
  docker compose exec -T db pg_dump -U "${POSTGRES_USER:-antrenor}" "${POSTGRES_DB:-antrenor}" \
    | gzip > "$HEDEF/antrenor-$GUN.sql.gz"
else
  pg_dump "${DATABASE_URL:?DATABASE_URL gerekli}" | gzip > "$HEDEF/antrenor-$GUN.sql.gz"
fi

# 14 gunden eski yedekleri sil
find "$HEDEF" -name 'antrenor-*.sql.gz' -mtime +14 -delete
echo "yedek tamam: $HEDEF/antrenor-$GUN.sql.gz"
