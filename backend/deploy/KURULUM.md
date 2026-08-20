# Sunucu Kurulumu — Veri Akışını Yayına Alma

Bu belge, uygulamanın duyuruları çekebilmesi için gereken sunucu kurulumunu anlatır.
Uygulama kodlamasına başlamadan bu adımların tamamlanması gerekir; çünkü mobil tarafta
kullanacağımız API adresi burada belirlenir.

---

## 0. Mimari — veri nereden nereye akıyor

```
  Federasyon siteleri (66 kaynak)
            │  her 30 dakikada bir
            ▼
      worker  ──►  PostgreSQL  ──►  api (REST)  ──►  Mobil uygulama
            │                                            ▲
            └──────────► Firebase (FCM) ─── push ─────────┘
```

* **worker** — federasyon sitelerini tarar, yeni duyuruları veritabanına yazar,
  yeni kayıt varsa Firebase'e bildirim gönderir. Tek bir süreç olarak çalışır.
* **api** — uygulamanın okuduğu REST uçları. Tarama yapmaz, sadece veritabanını okur.
* **Firebase (FCM)** — bildirimi taşıyan servis. Uygulama, takip ettiği her federasyonun
  konusuna (`fed_yuzme`, `fed_atletizm` …) kendisi abone olur; sunucuda cihaz kaydı tutulmaz.

Bu ayrım önemli: API birden fazla süreçle çalıştığı için tarama API'nin içinde olsaydı
aynı siteler paralel olarak defalarca çekilirdi.

---

## 1. Sunucu seçimi

**Türkiye'de bir sunucu kullanın.** Tarama sırasında iki federasyon sitesinin
(Kick Boks, Spor Toto) güvenlik duvarı, yurt dışı veri merkezi IP'lerini engelledi.
Türkiye'deki bir IP'den bu kaynakların da açılması bekleniyor.

| Seçenek | Aylık | Not |
|---|---|---|
| Türk sağlayıcı VPS (2 vCPU / 4 GB / 60 GB) | ~250–500 ₺ | **Önerilen.** TR IP, düşük gecikme |
| Hetzner / Contabo (Almanya) | ~5–8 € | Ucuz ama iki kaynak engelli kalır |
| Yönetilen PaaS (Render, Railway) | ~20 $ | Playwright ve kalıcı disk sorun çıkarır |

Minimum: **2 vCPU, 4 GB RAM, 40 GB disk.** Chromium (bot korumalı siteler için)
tarama sırasında kısa süreli ~1 GB RAM kullanır.

Alan adı: `antrenorapp.com` gibi bir alan adı alıp `api.antrenorapp.com` A kaydını
sunucu IP'sine yönlendirin. Uygulama bu adrese bağlanacak.

---

## 2. Kurulum — Docker ile (önerilen)

```bash
# Sunucuda
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git
sudo mkdir -p /opt/antrenor && sudo chown $USER /opt/antrenor
cd /opt/antrenor
git clone <depo-adresi> . && cd backend

cp .env.production.example .env.production
nano .env.production          # alan adı, parolalar, JWT_SECRET
openssl rand -hex 32          # JWT_SECRET için

mkdir -p secrets
# Firebase servis hesabı anahtarını buraya koyun:
#   secrets/fcm-service-account.json

docker compose --env-file .env.production up -d --build
docker compose logs -f worker    # ilk tarama ~8-10 dakika sürer
```

İlk tarama bittiğinde:

```bash
curl https://api.antrenorapp.com/health
curl https://api.antrenorapp.com/ready         # duyuru sayısı ve son tarama zamanı
curl "https://api.antrenorapp.com/v1/announcements?limit=3"
```

TLS sertifikası Caddy tarafından otomatik alınır; 80 ve 443 portlarının açık olması yeterli.

---

## 3. Kurulum — Docker'sız (systemd)

```bash
sudo apt install -y python3.12-venv postgresql nginx
sudo useradd -r -m -d /opt/antrenor antrenor
cd /opt/antrenor && git clone <depo-adresi> .
python3 -m venv venv && ./venv/bin/pip install -r backend/requirements.txt
./venv/bin/python -m playwright install --with-deps chromium

sudo -u postgres createuser antrenor -P
sudo -u postgres createdb antrenor -O antrenor

cp backend/.env.production.example backend/.env.production && nano backend/.env.production

sudo cp backend/deploy/antrenor-api.service /etc/systemd/system/
sudo cp backend/deploy/antrenor-worker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now antrenor-api antrenor-worker
sudo systemctl status antrenor-worker
```

TLS için `certbot --nginx` ve `127.0.0.1:8000`'e ters vekil yeterlidir.

---

## 4. Firebase (bildirim) kurulumu

1. [console.firebase.google.com](https://console.firebase.google.com) → yeni proje: `antrenor-app`
2. Android uygulaması ekle → paket adı (ör. `com.antrenorapp.mobile`) → `google-services.json` indir
3. iOS uygulaması ekle → bundle id → `GoogleService-Info.plist` indir
   *(iOS için ayrıca Apple Developer hesabından APNs anahtarı üretip Firebase'e yüklemek gerekir)*
4. Proje ayarları → Hizmet hesapları → **Yeni özel anahtar oluştur** → inen JSON dosyasını
   sunucuda `secrets/fcm-service-account.json` olarak kaydedin
5. `.env.production` içinde `FCM_PROJECT_ID` ve `PUSH_ENABLED=1` ayarlayın

Uygulama tarafında kod tek satır: kullanıcı bir federasyonu takibe aldığında
`FirebaseMessaging.instance.subscribeToTopic("fed_yuzme")`, bıraktığında `unsubscribeFromTopic`.

---

## 5. Uygulama veriyi nasıl alacak

| Ne zaman | İstek |
|---|---|
| İlk açılış | `GET /v1/federations` — 66 kurum, duyuru sayıları |
| Akış | `GET /v1/announcements?federation=yuzme,atletizm&limit=30` |
| Sonraki sayfa | `...&cursor=<önceki yanıttaki next_cursor>` |
| Yenileme (delta) | `...&since=<son görülen tarih>` — sadece yeni kayıtlar iner |
| Antrenör kursları | `GET /v1/announcements?tag=antrenor` |
| Arama | `GET /v1/announcements?q=vize semineri` |
| Bildirim | FCM konusu `fed_<slug>` → `data.announcement_id` ile derin bağlantı |

Uygulama, gelen kayıtları yerel veritabanında (Drift/Hive) saklar; böylece çevrimdışı da
son duyurular görünür ve her açılışta tüm liste yeniden indirilmez.

---

## 6. Yayın sonrası kontrol listesi

- [ ] `https://api.../ready` → `"ok": true` ve duyuru sayısı > 1000
- [ ] `https://api.../v1/status/sources` → hatalı kaynak sayısı 0'a yakın
- [ ] `https://api.../gizlilik` ve `https://api.../hesap-silme` tarayıcıda açılıyor
      *(mağaza formlarına bu adresleri gireceğiz)*
- [ ] `docker compose logs worker` → 30 dakikada bir "tarama tamam" satırı
- [ ] Yedekleme cron'u kurulu: `0 4 * * * /opt/antrenor/backend/deploy/yedekle.sh`
- [ ] Sunucu saat dilimi `Europe/Istanbul`

## 7. Güncelleme

```bash
cd /opt/antrenor && git pull
docker compose --env-file .env.production up -d --build
# veya systemd: sudo systemctl restart antrenor-api antrenor-worker
```

Bir federasyon sitesi tasarımını değiştirirse veri akışı durur; `/v1/status/sources`
bunu gösterir. Çözüm tek komut:

```bash
docker compose exec worker python scripts/discover_sources.py <federasyon-slug>
```
