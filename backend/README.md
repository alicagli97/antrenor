# Antrenör — Federasyon Duyuru Servisi (Backend)

Türkiye'deki spor federasyonlarının **duyuru ve haberlerini** otomatik toplayıp tek bir
akışta mobil uygulamaya sunan servis. Antrenörlerin kurs, vize, terfi, seminer ve mevzuat
duyurularını kaçırmaması için tasarlandı.

## Ne yapıyor

1. **Kaynak keşfi** — Her federasyonun sitesinde duyuru listesini otomatik bulur
   (WordPress REST → RSS → HTML liste sayfası → gerçek tarayıcı ile render).
2. **Tarama** — 30 dakikada bir tüm kaynakları çeker, duyuruları normalize eder.
3. **Sınıflandırma** — Başlıktan kategori (`kurs`, `mevzuat`, `musabaka`, `haber`, `duyuru`)
   ve etiket (`antrenor`, `vize`, `terfi`, `hakem`, `kulup`…) çıkarır.
4. **Tekilleştirme** — URL parmak iziyle aynı duyuru iki kez kaydedilmez.
5. **Bildirim** — Kullanıcının takip ettiği federasyondan yeni duyuru gelince FCM push.
6. **API** — Mobil uygulamanın kullandığı REST uçları + mağaza zorunluluğu olan web sayfaları.

## Kurulum

```bash
pip install -r requirements.txt
python -m playwright install chromium      # SPA/bot korumalı siteler için
cp .env.example .env                       # değerleri doldurun

python scripts/discover_sources.py         # kaynakları keşfet (data/sources.json)
python scripts/scrape.py                   # tek seferlik tarama
python scripts/coverage_report.py          # kapsama raporu
python scripts/robots_audit.py             # robots.txt denetimi
uvicorn app.main:app --reload              # API + zamanlayıcı
```

## Dizin yapısı

```
app/
  main.py                 FastAPI uygulaması + tarama zamanlayıcısı
  config.py               Ortam değişkenleri
  models.py               Veritabanı modelleri
  db.py                   Oturum yönetimi, federasyon kütüğü senkronu
  auth.py                 Parola özeti + JWT
  push.py                 Firebase Cloud Messaging (HTTP v1)
  api/routes.py           REST uçları
  api/schemas.py          İstek/yanıt şemaları
  web/pages.py            Gizlilik, hesap silme, destek sayfaları
  scraper/
    registry.py           Federasyon kütüğü (ad, site, branş, olimpik/para)
    discovery.py          Duyuru kaynağı otomatik keşfi
    extract.py            RSS / WP-JSON / genel HTML liste çıkarımı + sınıflandırma
    adapters.py           SPA ve bot korumalı siteler için özel adaptörler
    dates.py              Türkçe tarih ayrıştırma
    pipeline.py           Tarama hattı: çek → normalize → tekilleştir → kaydet
    http_client.py        Ortak HTTP istemcisi
scripts/
  discover_sources.py     Kaynak keşfi
  scrape.py               Tek seferlik tarama
  coverage_report.py      Kapsama raporu (data/coverage.json)
  build_report.py         Paylaşılabilir HTML rapor üretir
  robots_audit.py         Kaynakların robots.txt uyumunu denetler
  retag.py                Kayıtlı duyuruların kategori/etiketlerini yeniden hesaplar
  sniff_api.py            SPA sitelerinin arka plan JSON uçlarını yakalar
data/
  sources.json            Keşfedilen kaynaklar (federasyon → uç listesi)
  coverage.json           Son kapsama raporu
  antrenor.db             SQLite (geliştirme)
```

## API özeti

| Uç | Açıklama |
|---|---|
| `GET /v1/federations` | Federasyon listesi, duyuru sayıları |
| `GET /v1/announcements` | Akış: `federation`, `category`, `tag`, `q`, `since`, `cursor`, `limit` |
| `GET /v1/announcements/{id}` | Tek duyuru |
| `POST /v1/devices` | Push token kaydı + takip edilen federasyonlar |
| `PUT /v1/devices/follows` | Takip listesini güncelle |
| `POST /v1/auth/register` · `POST /v1/auth/login` | Hesap |
| `DELETE /v1/account` | **Uygulama içi hesap silme** (App Store 5.1.1(v)) |
| `POST /v1/account/deletion-request` | **Web üzerinden silme talebi** (Google Play) |
| `GET /v1/status/sources` | Kaynak sağlık durumu (hangi federasyon çekilemiyor) |
| `GET /gizlilik` · `/hesap-silme` · `/destek` | Mağaza zorunluluğu olan web sayfaları |

Örnek — antrenör kursu duyuruları:

```
GET /v1/announcements?tag=antrenor&limit=30
GET /v1/announcements?category=kurs&federation=yuzme,atletizm
GET /v1/announcements?q=vize%20semineri
```

## İçerik ve hukuk notu

* Duyurular federasyonların **herkese açık** resmî sayfalarından derlenir; her kayıtta
  federasyon adı ve **orijinal bağlantı** saklanır ve uygulamada gösterilir.
* Tam metin yerine özet gösterilip "kaynağa git" bağlantısı verilir — telif ve
  "içeriğin resmî hâli kaynaktadır" ilkesi için.
* İstekler `From` / `X-Contact` başlıklarıyla kimlik bildirir, eşzamanlılık düşük tutulur
  (varsayılan 6) ve 30 dakikada bir çalışır.
* Uygulama, federasyonların resmî uygulaması değildir; bu, mağaza açıklamasında ve
  uygulama içi "Hakkında" ekranında açıkça belirtilmelidir (marka karışıklığı reddi riski).

## Dağıtım

Üç seçenek belgelendi:

| Belge | Ne için |
|---|---|
| [deploy/BU_BILGISAYARDA.md](deploy/BU_BILGISAYARDA.md) | **Şu anki kurulum** — sunucu bu bilgisayarda, telefon aynı Wi-Fi'dan bağlanıyor |
| [deploy/KURULUM.md](deploy/KURULUM.md) | VPS'e taşıma (Docker Compose veya systemd) |
| `docker-compose.yml` | api + worker + PostgreSQL + Caddy (otomatik HTTPS) |

* **Süreç ayrımı:** API tarama yapmaz (`ENABLE_SCHEDULER=0`); tarama `scripts/worker.py`
  içinde tek süreç olarak çalışır. Aksi halde her API worker'ı aynı siteleri tekrar çeker.
* **Zamanlayıcı:** `app.main` içindeki döngü uygulama ile birlikte çalışır. Ayrı süreç
  isterseniz `scripts/scrape.py`'yi cron/systemd timer ile çalıştırın.
* **Veritabanı:** Üretimde PostgreSQL (`DATABASE_URL`).
* **Render:** Playwright kullanan kaynaklar için sunucuda chromium bağımlılıkları gerekir.
