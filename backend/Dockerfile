# Antrenör backend — API ve tarama isçisi ayni imajdan calisir.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Europe/Istanbul

WORKDIR /app

# Kok sertifikalar + saat dilimi (Türkçe tarihler ve TLS icin)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# JS ile calisan / bot dogrulamasi olan federasyon siteleri icin tarayici.
# --with-deps gerekli sistem kutuphanelerini de kurar.
RUN python -m playwright install --with-deps chromium

COPY . .

# Root olmayan kullanici
RUN useradd -m -u 10001 antrenor \
    && mkdir -p /app/data \
    && chown -R antrenor:antrenor /app /ms-playwright 2>/dev/null || true
USER antrenor

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
