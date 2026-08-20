# Mağaza Uyumluluk Haritası

`App_Store_Yayinlama_Prosedurleri.docx` ve `Play_Store_Yayinlama_Prosedurleri.docx`
dosyalarındaki gereklilikler ile projedeki karşılıkları.

Durum: ✅ hazır · 🟡 arayüz aşamasında yapılacak · ⬜ hesap/kurumsal iş (sizde)

## 1. Hesap silme zorunluluğu (her iki mağaza)

| Gereklilik | Kaynak | Durum | Karşılığı |
|---|---|---|---|
| Uygulama içinden hesap silme | Apple 5.1.1(v) | ✅ | `DELETE /v1/account` — gerçek silme, dondurma değil |
| Web üzerinden silme talebi | Google User Data Policy | ✅ | `/hesap-silme` sayfası + `POST /v1/account/deletion-request` |
| Kişisel verilerin de silinmesi | Her ikisi | ✅ | `_purge_user()` cihaz kayıtları ve takipleri de siler |
| Silme akışının uygulamada bulunabilir olması | Apple | 🟡 | Profil → Ayarlar → "Hesabımı Sil" ekranı (arayüz aşaması) |
| Sign in with Apple token iptali | Apple | 🟡 | `User.apple_sub` / `apple_refresh_token` alanları hazır; Apple ile giriş eklenirse revoke çağrısı yazılacak |
| Play Console Veri Güvenliği formunda silme beyanı | Google | ⬜ | Form doldurulurken "hesap silme sunuluyor" işaretlenecek |

> Not: Apple test ekibi tipik olarak **giriş yap → hesabı sil → aynı bilgilerle tekrar giriş**
> akışını dener. `register` ucu, silinmiş e-postanın yeniden kaydına izin verir; eski veri kalmaz.

## 2. Gizlilik ve veri bildirimleri

| Gereklilik | Durum | Karşılığı |
|---|---|---|
| Gizlilik politikası URL'i | ✅ | `/gizlilik` |
| Toplanan verinin gerçekle uyuşması | ✅ | Yalnızca e-posta, görünen ad, push token, takip tercihleri |
| Hassas izin kullanılmaması | ✅ | Konum/kamera/mikrofon/kişiler/sağlık verisi yok |
| App Privacy etiketleri | ⬜ | App Store Connect'te: "Kişiye bağlı: e-posta"; "Bağlı değil: tanımlayıcılar" |
| Play Veri Güvenliği formu | ⬜ | Aynı beyan Play Console'da |
| Reklam kimliği / izleme | ✅ | Kullanılmıyor (form beyanını kolaylaştırır) |

## 3. Teknik gereklilikler

| Gereklilik | Durum | Not |
|---|---|---|
| Android App Bundle (AAB) | 🟡 | Flutter `flutter build appbundle` |
| Güncel targetSdkVersion | 🟡 | Flutter sürümü güncel; derleme aşamasında doğrulanacak |
| Play App Signing | ⬜ | Play Console'da etkinleştirilecek |
| Backend'in inceleme sırasında ayakta olması | 🟡 | API'nin 7/24 erişilebilir olması gerekir (Apple bunu açıkça istiyor) |
| Çökme oranı < %0,5 | 🟡 | Kapalı test kanalı ile ölçülecek |

## 4. Mağaza girişi (store listing)

| Gereklilik | Durum | Not |
|---|---|---|
| Uygulama adı, kısa/uzun açıklama | ⬜ | Metinler yazılacak |
| En az 2 ekran görüntüsü (Play), tüm cihaz boyutları (Apple) | 🟡 | Arayüz bitince |
| 512×512 simge + feature graphic (Play) | 🟡 | Logo aşamasında |
| Kategori ve yaş derecelendirmesi | ⬜ | "Spor", 3+/4+ |
| Rakip mağazalara atıf yapılmaması | ✅ | Metinlerde dikkat edilecek |
| İletişim bilgileri | ✅ | `/destek` sayfası + destek e-postası |

## 5. İnceleme için test erişimi

| Gereklilik | Durum | Not |
|---|---|---|
| Demo hesap | 🟡 | Uygulama girişsiz de çalışacak şekilde tasarlandı; yine de bir demo hesap verilecek |
| Review Notes / test adımları | ⬜ | "Duyuru akışı → federasyon takibi → hesap silme" adımları yazılacak |
| IAP / abonelik | — | Şimdilik yok |

## 6. Reddedilme riski taşıyan özel noktalar

1. **Marka karışıklığı (Apple 4.1 / 5.2):** Uygulama federasyonların resmî uygulaması
   değil. Ad, logo ve açıklamada federasyon amblemleri kullanılmamalı; "resmî olmayan,
   bağımsız duyuru toplayıcı" ifadesi açıklamada yer almalı.
2. **Minimum işlevsellik (Apple 4.2):** Sadece web içeriğini listeleyen uygulamalar
   reddedilebiliyor. Bunu aşmak için: federasyon takibi, kategori/etiket filtresi,
   antrenör kursu bildirimleri, arama, kaydetme gibi katma değerli özellikler.
3. **İçerik hakları:** Duyurular özet + kaynak bağlantısı olarak gösterilir; tam metin
   kopyalanıp sahiplenilmez.
4. **Boş/hatalı kaynak:** Bir federasyon sitesi tasarımını değiştirdiğinde akış
   kesilmemeli — `GET /v1/status/sources` ile izlenir, `discover_sources.py` yeniden
   çalıştırılarak kaynak otomatik güncellenir.
