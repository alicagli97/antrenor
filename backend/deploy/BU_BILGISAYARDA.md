# Sunucuyu Bu Bilgisayarda Çalıştırmak

Seçim: veri akışını şimdilik bu bilgisayar sağlayacak. Bu belge kurulumu, telefonun
veriye nasıl ulaşacağını ve yayın öncesi nelerin değişmesi gerektiğini anlatır.

---

## 1. Kurulum (tek seferlik)

PowerShell'i **yönetici olarak** açın:

```powershell
cd C:\Users\PEGASUS\Desktop\ben\antrenör\backend
powershell -ExecutionPolicy Bypass -File scripts\windows\kur.ps1
```

Bu betik üç şey yapar:
* Windows Güvenlik Duvarı'nda **8000** portunu yalnızca yerel ağa açar (telefon bağlanabilsin diye)
* Bilgisayar açıldığında sunucuyu başlatan bir görev oluşturur
* Uyku ayarını gösterir — **uyuyan bilgisayar veri akışını keser**

Uykuyu kapatmak için:

```powershell
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
```

## 2. Başlatma / durdurma

```powershell
powershell -ExecutionPolicy Bypass -File scripts\windows\baslat.ps1   # başlat
powershell -ExecutionPolicy Bypass -File scripts\windows\durdur.ps1   # durdur
```

`baslat.ps1` iki süreç çalıştırır:

| Süreç | Görev | Günlük |
|---|---|---|
| `uvicorn app.main:app` | REST uçları, port 8000 | `data/api.log` |
| `scripts/worker.py` | 30 dakikada bir federasyon taraması | `data/worker.log` |

Durum kontrolü:

```powershell
curl http://127.0.0.1:8000/ready
```

## 3. Telefon veriye nasıl ulaşacak

**Geliştirme sırasında (aynı Wi-Fi):** telefon ve bilgisayar aynı ağda olduğu sürece
uygulama doğrudan bağlanır:

```
http://192.168.1.168:8000
```

Bu adres bilgisayarın yerel IP'si. Modem yeniden başlarsa değişebilir; sabitlemek için
modem arayüzünden bu bilgisayara **statik IP** verin (DHCP rezervasyonu).

Flutter tarafında iki nokta:
* Android, varsayılan olarak şifresiz `http://` bağlantılarını engeller. Geliştirme için
  `android/app/src/main/res/xml/network_security_config.xml` içinde bu IP'ye izin vereceğiz.
* iOS'ta aynı şey `NSAppTransportSecurity` ile yapılır.

Yayına çıkarken bu izinler kaldırılır; adres HTTPS olur.

## 4. İnternete açmak (Wi-Fi dışından erişim)

Uygulamayı kendi telefonunuzda dışarıdayken denemek veya beta testçilere vermek için
sunucunun internetten erişilebilir olması gerekir. Modem portu açmak yerine **tünel**
kullanın — ISP engellerini ve değişken IP sorununu ortadan kaldırır.

| Yöntem | Ücret | Ne verir | Ne zaman |
|---|---|---|---|
| **Cloudflare Tunnel** | Ücretsiz (alan adı ~10 $/yıl) | `https://api.alanadiniz.com` sabit adres, otomatik TLS | Önerilen |
| ngrok | Ücretsiz katman | Her açılışta değişen `https://xxx.ngrok-free.app` | Hızlı deneme |
| Tailscale Funnel | Ücretsiz | `https://<makine>.<ag>.ts.net` | Alan adı istemiyorsanız |

Cloudflare Tunnel kurulumu (alan adınız Cloudflare'de olmalı):

```powershell
winget install --id Cloudflare.cloudflared
cloudflared tunnel login
cloudflared tunnel create antrenor
cloudflared tunnel route dns antrenor api.alanadiniz.com
cloudflared tunnel run --url http://127.0.0.1:8000 antrenor
```

Kalıcı çalışması için: `cloudflared service install`

Hızlı deneme (alan adı gerekmez):

```powershell
winget install --id ngrok.ngrok
ngrok http 8000
```

## 5. Bu kurulumun sınırları — yayın öncesi bilinmesi gerekenler

Bu bilgisayar geliştirme ve beta için yeterli. Ancak mağazaya gönderirken üç risk var:

1. **Apple, inceleme sırasında arka ucun ayakta olmasını şart koşuyor.** İncelemeci
   uygulamayı açtığında bilgisayar kapalıysa veya uykudaysa uygulama boş görünür ve
   ret gelir (mağaza prosedürleri belgesindeki "backend servislerinin aktif olması" maddesi).
2. **Kesinti = veri akışı durur.** Elektrik, internet veya Windows güncellemesi
   sonrası yeniden başlatma sırasında duyurular güncellenmez.
3. **Ev internetinin yükleme hızı ve ISP kuralları** kullanıcı sayısı arttıkça sınır olur.

Önerim: uygulamayı bu bilgisayarda geliştirelim, mağazaya göndermeden **1 hafta önce**
aylık ~250–500 ₺'lik bir sunucuya taşıyalım. Taşıma işi kısa: `deploy/KURULUM.md`
zaten hazır, veritabanını kopyalayıp aynı komutları çalıştırmak yeterli. Uygulamadaki
tek değişiklik API adresi olur — bunu baştan ayarlanabilir yazacağız.

## 5b. Yerel köprü (GitHub'a geçtikten sonra)

Veri akışı artık GitHub Actions'ta çalışıyor; bu bilgisayarın tek görevi, Cloudflare
koruması nedeniyle GitHub'dan erişilemeyen Basketbol Federasyonu:

```powershell
cd C:\Users\PEGASUS\Desktop\ben\antrenör\backend
python scripts\local_bridge.py --watch
```

6 saatte bir tarar, değişiklik varsa depoya gönderir. Kapalı olması diğer 63 kaynağı
etkilemez.

## 6. Veritabanı

Şimdilik SQLite (`data/antrenor.db`) kullanılıyor; bu ölçek için fazlasıyla yeterli
(1.330 duyuru ≈ 2 MB). Sunucuya taşırken PostgreSQL'e geçilir, kod değişmez —
sadece `DATABASE_URL` değişir.

Yedek almak için `data/antrenor.db` dosyasını kopyalamak yeterli:

```powershell
Copy-Item data\antrenor.db "data\yedek-$(Get-Date -Format yyyyMMdd).db"
```
