# -*- coding: utf-8 -*-
"""GitHub Pages icin statik sayfalari uretir.

Magaza formlarina verilecek genel erisime acik adresler:
    /                 tanitim + veri akisi durumu
    /gizlilik.html    Gizlilik Politikasi (her iki magaza icin zorunlu)
    /kosullar.html    Kullanim Kosullari / EULA (abonelik satisi icin zorunlu)
    /destek.html      Destek / iletisim (store listing icin zorunlu)
    /veri-silme.html  Kullanici verisi ve silme aciklamasi
"""
from __future__ import annotations

import json
import pathlib
from datetime import datetime

BASE = pathlib.Path(__file__).resolve().parents[2]
DOCS = BASE / "docs"
META = DOCS / "api" / "v1" / "meta.json"

APP_NAME = "Antrenör"
SUPPORT_EMAIL = "destek@antrenorapp.com"     # kendi adresinizle degistirin

STYLE = """
:root{--bg:#EDF0F3;--card:#fff;--line:#DCE2E8;--ink:#101720;--ink2:#4C5966;
      --ink3:#7A8794;--accent:#A8201A;--ok:#12674A}
@media (prefers-color-scheme:dark){:root{--bg:#0C1015;--card:#141A21;--line:#28323D;
      --ink:#E7ECF1;--ink2:#A7B3BF;--ink3:#7B8896;--accent:#E4635A;--ok:#4CBE92}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
     font:16px/1.62 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:760px;margin:0 auto;padding:40px 20px 80px;display:flex;
      flex-direction:column;gap:24px}
.eyebrow{font:600 11px/1 ui-monospace,Consolas,monospace;letter-spacing:.16em;
         text-transform:uppercase;color:var(--accent)}
h1{font-size:32px;line-height:1.12;letter-spacing:-.02em;margin:8px 0 0}
h2{font-size:19px;margin:0 0 6px}
p,ul{margin:0}
ul{padding-left:20px;display:flex;flex-direction:column;gap:6px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;
      padding:20px 22px;display:flex;flex-direction:column;gap:10px}
.muted{color:var(--ink3);font-size:14px}
a{color:var(--accent)}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px 18px}
.stat .k{font:600 10px/1 ui-monospace,Consolas,monospace;letter-spacing:.12em;
         text-transform:uppercase;color:var(--ink3)}
.stat .v{font:700 26px/1.1 ui-monospace,Consolas,monospace;margin-top:8px;
         font-variant-numeric:tabular-nums}
code{background:var(--bg);border:1px solid var(--line);border-radius:5px;
     padding:2px 6px;font-size:13.5px}
nav{display:flex;gap:16px;flex-wrap:wrap;font-size:14px;border-top:1px solid var(--line);
    padding-top:16px}
"""


def page(title: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} — {APP_NAME}</title><style>{STYLE}</style></head>
<body><div class="wrap">{body}
<nav><a href="/">Ana sayfa</a><a href="/gizlilik.html">Gizlilik</a>
<a href="/kosullar.html">Kullanım Koşulları</a>
<a href="/veri-silme.html">Veri silme</a><a href="/destek.html">Destek</a></nav>
</div></body></html>"""


def index_page(meta: dict) -> str:
    kurs = meta.get("categories", {}).get("kurs", 0)
    return page("Ana Sayfa", f"""
<header>
  <div class="eyebrow">Türkiye spor federasyonları</div>
  <h1>{APP_NAME}</h1>
  <p class="muted">Federasyon duyurularını tek akışta toplayan bağımsız uygulama.
  Antrenör kursu, vize, terfi ve seminer duyurularını kaçırmayın.</p>
</header>

<div class="stats">
  <div class="stat"><div class="k">Kurum</div><div class="v">{len(meta.get('federation_counts', {}))}</div></div>
  <div class="stat"><div class="k">Duyuru</div><div class="v">{meta.get('total', 0)}</div></div>
  <div class="stat"><div class="k">Kurs / vize</div><div class="v">{kurs}</div></div>
</div>

<div class="card">
  <h2>Veri akışı</h2>
  <p>Duyurular saatte bir taranır ve açık veri olarak yayınlanır:</p>
  <ul>
    <li><code>/api/v1/meta.json</code> — sürüm ve son güncelleme</li>
    <li><code>/api/v1/federations.json</code> — kurum listesi</li>
    <li><code>/api/v1/feed.json</code> — son 300 duyuru</li>
    <li><code>/api/v1/fed/&lt;slug&gt;.json</code> — federasyon bazında</li>
    <li><code>/api/v1/tag/antrenor.json</code> — antrenörlük duyuruları</li>
  </ul>
  <p class="muted">Son güncelleme: {meta.get('generated_at', '—')}</p>
</div>

<div class="card">
  <h2>Kaynak ve sorumluluk</h2>
  <p>Duyurular federasyonların herkese açık resmî sayfalarından derlenir. Her kayıtta
  kaynak kurum ve orijinal bağlantı gösterilir; içeriğin resmî ve bağlayıcı hâli ilgili
  federasyonun kendi sitesindedir. {APP_NAME}, federasyonlarla resmî bir bağlantısı
  olmayan bağımsız bir uygulamadır.</p>
</div>""")


def privacy_page() -> str:
    return page("Gizlilik Politikası", f"""
<h1>Gizlilik Politikası</h1>
<p class="muted">Son güncelleme: {datetime.now().strftime('%d.%m.%Y')}</p>

<div class="card">
  <h2>Kısa özet</h2>
  <p><strong>{APP_NAME} sizden kişisel veri toplamaz.</strong> Uygulamada hesap
  oluşturulmaz, giriş yapılmaz. Takip ettiğiniz federasyonlar ve okuma
  tercihleriniz yalnızca kendi telefonunuzda saklanır; bize gönderilmez.</p>
  <p>Ücretsiz sürümde reklam gösterildiği için reklam sağlayıcısı (Google AdMob)
  cihazınıza ait bazı verileri kendi adına işler. Aşağıda tam olarak
  açıklanmıştır.</p>
</div>

<div class="card">
  <h2>Reklamlar</h2>
  <p>Ücretsiz sürümde duyuruları açarken kısa reklamlar gösterilir. Reklamlar
  <strong>Google AdMob</strong> tarafından sunulur ve AdMob bu sırada cihaz
  reklam kimliğinizi, yaklaşık konum bilgisini (IP tabanlı, şehir düzeyinde),
  cihaz ve uygulama bilgilerini reklam gösterimi, ölçüm ve kötüye kullanım
  önleme amacıyla işler. Bu veriler bize aktarılmaz; biz yalnızca toplam
  gösterim ve kazanç istatistiklerini görürüz.</p>
  <p>Google'ın bu verileri nasıl kullandığı:
  <a href="https://policies.google.com/technologies/partner-sites">Google
  Gizlilik ve Şartlar</a>. Kişiselleştirilmiş reklamı Android'de
  <em>Ayarlar → Google → Reklamlar</em>, iOS'ta <em>Ayarlar → Gizlilik ve
  Güvenlik → İzleme</em> bölümünden kapatabilirsiniz.</p>
  <p><strong>Premium abonelikte hiç reklam gösterilmez</strong> ve reklam
  sağlayıcısına hiçbir veri gitmez.</p>
</div>

<div class="card">
  <h2>Abonelik ve ödeme</h2>
  <p>Premium abonelik Google Play veya App Store üzerinden satın alınır.
  <strong>Ödeme bilgileriniz bize hiçbir zaman ulaşmaz;</strong> kart bilgisi,
  fatura adresi veya mağaza hesabınızın kimliği tarafımızca görülmez ve
  saklanmaz. Uygulama mağazadan yalnızca "bu cihazda etkin abonelik var mı"
  bilgisini alır ve bunu telefonun kendi belleğinde tutar.</p>
  <p>Aboneliği, telefonunuzun mağaza ayarlarındaki abonelikler bölümünden
  istediğiniz zaman iptal edebilirsiniz.</p>
</div>

<div class="card">
  <h2>Bildirimler</h2>
  <p>Bildirim açtığınızda uygulama, seçtiğiniz federasyonun Firebase Cloud Messaging
  konusuna abone olur. Bu abonelik cihazınız ile Google'ın bildirim servisi arasındadır;
  bizde cihaz kimliği veya iletişim bilgisi saklanmaz. Bildirimleri telefon ayarlarından
  kapatabilirsiniz.</p>
</div>

<div class="card">
  <h2>Bizim toplamadığımız veriler</h2>
  <ul>
    <li>Ad, e-posta, telefon numarası</li>
    <li>Kişiler, kamera, mikrofon, sağlık verisi, hassas konum</li>
    <li>Ödeme ve kart bilgileri</li>
    <li>Hangi duyuruyu okuduğunuz, ne kadar kullandığınız</li>
  </ul>
  <p>Bu veriler bizim tarafımızdan toplanmaz, satılmaz veya pazarlama amacıyla
  paylaşılmaz. Reklam sağlayıcısının kendi adına işlediği veriler yukarıdaki
  "Reklamlar" bölümünde ayrıca belirtilmiştir.</p>
</div>

<div class="card">
  <h2>İçerik kaynağı</h2>
  <p>Duyurular Türkiye'deki spor federasyonlarının herkese açık resmî sitelerinden
  derlenir. Uygulama özet gösterir ve kaynağa bağlantı verir.</p>
</div>

<div class="card">
  <h2>Haklarınız ve iletişim</h2>
  <p>KVKK ve GDPR kapsamındaki talepleriniz için
  <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>. Uygulama hesabı olmadığından
  silinecek sunucu kaydı bulunmaz; ayrıntı için
  <a href="/veri-silme.html">veri silme sayfası</a>.</p>
</div>""")


def terms_page() -> str:
    return page("Kullanım Koşulları", f"""
<h1>Kullanım Koşulları</h1>
<p class="muted">Son güncelleme: {datetime.now().strftime('%d.%m.%Y')}</p>

<div class="card">
  <h2>Uygulama nedir</h2>
  <p>{APP_NAME}, Türkiye'deki spor federasyonlarının herkese açık resmî
  sitelerinde yayımlanan duyuru, faaliyet takvimi ve mevzuat belgelerini tek
  yerde toplayan bağımsız bir uygulamadır. Hiçbir federasyonla, Gençlik ve Spor
  Bakanlığı ile veya resmî bir kurumla bağlantısı, ortaklığı ya da onay ilişkisi
  yoktur.</p>
</div>

<div class="card">
  <h2>İçeriğin doğruluğu</h2>
  <p>Uygulamadaki kayıtlar kaynak sitelerden otomatik olarak derlenir ve özet
  biçiminde sunulur. <strong>Bağlayıcı ve resmî olan, federasyonun kendi
  sitesindeki asıl metindir.</strong> Kaynakta yapılan değişiklikler uygulamaya
  gecikmeli yansıyabilir; teknik nedenlerle bir duyuru hiç alınamayabilir.
  Kurs, vize, seminer veya müsabaka gibi hak doğuran işlemlerde son kontrolü
  federasyonun resmî sayfasından yapmak kullanıcının sorumluluğundadır.
  Uygulama, eksik veya gecikmiş bilgiden doğan sonuçlardan sorumlu tutulamaz.</p>
</div>

<div class="card">
  <h2>Ücretsiz sürüm ve reklamlar</h2>
  <p>Ücretsiz sürümde bir duyuruyu açmak için kısa bir ödüllü reklam izlenir ve
  aynı anda en fazla 1 federasyon takip edilebilir. Reklamlar Google AdMob
  tarafından sunulur; ayrıntısı
  <a href="/gizlilik.html">Gizlilik Politikası</a>'ndadır.</p>
</div>

<div class="card">
  <h2>Premium abonelik</h2>
  <ul>
    <li>Premium abonelikte reklam gösterilmez ve takip edilebilecek federasyon
    sayısında sınır yoktur.</li>
    <li>Abonelik aylık veya yıllık olarak, uygulama içinden Google Play ya da
    App Store üzerinden satın alınır. Güncel fiyat satın alma ekranında,
    kendi para biriminizde gösterilir.</li>
    <li>Abonelik, dönem bitiminden en az 24 saat önce iptal edilmediği sürece
    kendiliğinden yenilenir ve ücret mağaza hesabınızdan tahsil edilir.</li>
    <li>İptal, telefonunuzun mağaza ayarlarındaki abonelikler bölümünden
    yapılır. İptal sonrasında premium haklar ödenmiş dönemin sonuna kadar
    devam eder.</li>
    <li>İade talepleri, ödemenin alındığı mağazanın (Google Play / Apple)
    kendi iade kuralları çerçevesinde doğrudan mağazaya iletilir. Ödemeye
    tarafımızca erişim olmadığından iadeyi biz gerçekleştiremeyiz.</li>
    <li>Yeni cihaza geçtiğinizde aboneliğinizi, Ayarlar ekranındaki
    "Satın alımları geri yükle" ile taşıyabilirsiniz.</li>
  </ul>
</div>

<div class="card">
  <h2>Uygun kullanım</h2>
  <p>Uygulamayı, hizmeti aksatacak biçimde otomatik araçlarla kullanmamayı,
  reklam gösterimlerini yapay olarak artırmaya veya ödeme sistemini atlatmaya
  çalışmamayı kabul edersiniz. Bu tür kullanım tespit edilirse erişim
  kısıtlanabilir.</p>
</div>

<div class="card">
  <h2>Telif ve markalar</h2>
  <p>Federasyonlara ait duyuru metinleri, belgeler, adlar ve amblemler ilgili
  kurumlara aittir; uygulamada kaynak gösterilerek ve kaynağa bağlantı verilerek
  yer alır. Bir federasyon kendisine ait içeriğin kaldırılmasını talep ederse
  ilgili kayıtlar kaldırılır.</p>
</div>

<div class="card">
  <h2>Değişiklikler ve iletişim</h2>
  <p>Bu koşullar güncellenebilir; güncel sürüm her zaman bu sayfada yayımlanır.
  Soru ve talepleriniz için
  <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>.</p>
</div>""")


def deletion_page() -> str:
    return page("Veri Silme", f"""
<h1>Verilerin Silinmesi</h1>

<div class="card">
  <h2>Hesap oluşturulmuyor</h2>
  <p>{APP_NAME} kullanıcı hesabı açmaz ve sunucusunda kişisel veri tutmaz.
  Bu nedenle silinmesi gereken bir hesap kaydı bulunmaz.</p>
</div>

<div class="card">
  <h2>Cihazınızdaki veriler</h2>
  <p>Takip ettiğiniz federasyonlar, kaydettiğiniz duyurular ve okuma geçmişi
  yalnızca telefonunuzda saklanır. Tamamını silmek için:</p>
  <ul>
    <li><strong>Uygulama içinden:</strong> Ayarlar → Verileri Sıfırla</li>
    <li><strong>Android:</strong> Ayarlar → Uygulamalar → {APP_NAME} → Depolama → Verileri temizle</li>
    <li><strong>iOS:</strong> Uygulamayı kaldırmak tüm yerel veriyi siler</li>
  </ul>
</div>

<div class="card">
  <h2>Bildirim abonelikleri</h2>
  <p>Bildirimleri kapattığınızda veya uygulamayı kaldırdığınızda konu abonelikleri
  sona erer. Talep etmeniz hâlinde yardımcı oluruz:
  <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>.</p>
</div>

<div class="card">
  <h2>İleride hesap eklenirse</h2>
  <p>Uygulamaya hesap özelliği eklenirse, uygulama içinden ve bu sayfadan hesap silme
  imkânı sunulacaktır (App Store 5.1.1(v) ve Google Play Kullanıcı Verileri Politikası).</p>
</div>""")


def support_page() -> str:
    return page("Destek", f"""
<h1>Destek</h1>

<div class="card">
  <p>Soru, hata bildirimi ve içerik düzeltme talepleri için
  <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>.</p>
</div>

<div class="card">
  <h2>Sık sorulanlar</h2>
  <ul>
    <li><strong>Duyurular ne sıklıkla güncellenir?</strong> Saatte bir tüm federasyon
    siteleri taranır.</li>
    <li><strong>Bir duyuru eksik görünüyor.</strong> Federasyon sitesindeki değişiklikleri
    bize bildirin, kaynağı güncelleyelim.</li>
    <li><strong>Federasyon eklenmesini istiyorum.</strong> Kurum adı ve site adresini gönderin.</li>
    <li><strong>Bu resmî bir federasyon uygulaması mı?</strong> Hayır. Bağımsız bir
    duyuru toplayıcıdır; içeriğin resmî hâli federasyonların kendi sitelerindedir.</li>
    <li><strong>Aboneliğimi nasıl iptal ederim?</strong> Telefonunuzun mağaza
    ayarlarındaki abonelikler bölümünden. Uygulamada Ayarlar → Aboneliği yönet
    sizi doğrudan oraya götürür.</li>
    <li><strong>Yeni telefona geçtim, premium gitti.</strong> Ayarlar →
    Satın alımları geri yükle. Mağaza hesabınız aynı olmalıdır.</li>
    <li><strong>Neden duyuru açarken reklam çıkıyor?</strong> Uygulamanın
    taraması ve yayını ücretsiz sürümde reklamla karşılanıyor. Premium
    abonelikte hiç reklam gösterilmez.</li>
  </ul>
</div>""")


def main() -> None:
    meta = json.loads(META.read_text(encoding="utf-8")) if META.exists() else {}
    DOCS.mkdir(parents=True, exist_ok=True)
    (DOCS / ".nojekyll").write_text("", encoding="utf-8")
    (DOCS / "index.html").write_text(index_page(meta), encoding="utf-8")
    (DOCS / "gizlilik.html").write_text(privacy_page(), encoding="utf-8")
    (DOCS / "kosullar.html").write_text(terms_page(), encoding="utf-8")
    (DOCS / "veri-silme.html").write_text(deletion_page(), encoding="utf-8")
    (DOCS / "destek.html").write_text(support_page(), encoding="utf-8")
    print(f"statik sayfalar yazildi -> {DOCS}")


if __name__ == "__main__":
    main()
