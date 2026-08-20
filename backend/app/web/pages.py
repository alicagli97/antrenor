# -*- coding: utf-8 -*-
"""Mağaza zorunluluklarını karşılayan genel erişimli web sayfaları.

* /hesap-silme  -> Google Play User Data Policy: web üzerinden hesap silme talebi
* /gizlilik     -> Her iki mağazanın istediği gizlilik politikası URL'i
* /destek       -> Store listing'de zorunlu iletişim/destek sayfası
"""
from __future__ import annotations

from ..config import APP_NAME, SUPPORT_EMAIL

_STYLE = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin:0; font: 16px/1.65 -apple-system, "Segoe UI", Roboto, sans-serif;
       background:#f6f7f9; color:#14181f; }
@media (prefers-color-scheme: dark) { body { background:#0f1216; color:#e8ecf2; }
  .card { background:#171b21 !important; border-color:#242a33 !important; }
  input { background:#0f1216 !important; color:#e8ecf2 !important; border-color:#2a313b !important; } }
.wrap { max-width: 760px; margin: 0 auto; padding: 32px 20px 64px; }
.card { background:#fff; border:1px solid #e4e8ee; border-radius:14px; padding:24px; margin:18px 0; }
h1 { font-size: 26px; margin: 8px 0 4px; }
h2 { font-size: 19px; margin: 26px 0 8px; }
a { color:#1e6bd6; }
input { width:100%; padding:12px 14px; border:1px solid #cfd6e0; border-radius:10px; font-size:16px; }
button { margin-top:12px; padding:12px 20px; border:0; border-radius:10px; background:#1e6bd6;
         color:#fff; font-size:16px; font-weight:600; cursor:pointer; }
.muted { color:#6b7480; font-size:14px; }
ul { padding-left: 20px; }
"""


def _layout(title: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {APP_NAME}</title><style>{_STYLE}</style></head>
<body><div class="wrap">{body}
<p class="muted">İletişim: <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a></p>
</div></body></html>"""


def account_deletion_html() -> str:
    body = f"""
<h1>Hesap Silme</h1>
<p>{APP_NAME} hesabınızı ve bağlı tüm kişisel verilerinizi kalıcı olarak silebilirsiniz.
Silme işlemi için uygulamayı yeniden yüklemenize gerek yoktur.</p>

<div class="card">
  <h2>Uygulama içinden</h2>
  <p><strong>Profil → Ayarlar → Hesabımı Sil</strong> adımlarını izleyin. Onaydan sonra hesabınız
  ve verileriniz kalıcı olarak silinir.</p>
</div>

<div class="card">
  <h2>Web üzerinden</h2>
  <p>E-posta adresinizi girin; adresinize gönderilecek doğrulama bağlantısını onayladığınızda
  hesabınız kalıcı olarak silinir.</p>
  <form method="post" action="/v1/account/deletion-request" id="f">
    <input type="email" name="email" id="email" placeholder="ornek@eposta.com" required>
    <button type="submit">Silme talebi gönder</button>
  </form>
  <p class="muted" id="msg"></p>
</div>

<div class="card">
  <h2>Silinen veriler</h2>
  <ul>
    <li>Hesap bilgileri (e-posta, görünen ad)</li>
    <li>Takip ettiğiniz federasyon tercihleri</li>
    <li>Bildirim için kayıtlı cihaz belirteçleri</li>
    <li>Kaydettiğiniz duyurular ve uygulama içi tercihler</li>
  </ul>
  <p>Bu veriler talebin onaylanmasının ardından <strong>en geç 30 gün içinde</strong> tüm
  sistemlerden (yedekler dâhil) kalıcı olarak silinir. Yasal saklama yükümlülüğü bulunan
  kayıt tutulmamaktadır.</p>
</div>

<script>
document.getElementById('f').addEventListener('submit', async (e) => {{
  e.preventDefault();
  const email = document.getElementById('email').value;
  const r = await fetch('/v1/account/deletion-request', {{
    method: 'POST', headers: {{'Content-Type': 'application/json'}},
    body: JSON.stringify({{email}})
  }});
  const d = await r.json().catch(() => ({{}}));
  document.getElementById('msg').textContent = d.message || 'Talebiniz alındı.';
}});
</script>"""
    return _layout("Hesap Silme", body)


def privacy_html() -> str:
    body = f"""
<h1>Gizlilik Politikası</h1>
<p class="muted">Son güncelleme: Ağustos 2026</p>

<div class="card">
  <h2>Toplanan veriler</h2>
  <ul>
    <li><strong>Hesap verisi:</strong> e-posta adresi ve görünen ad (yalnızca kayıt olursanız).</li>
    <li><strong>Cihaz belirteci:</strong> bildirim gönderebilmek için Firebase push token.</li>
    <li><strong>Tercihler:</strong> takip ettiğiniz federasyonlar ve bildirim ayarları.</li>
  </ul>
  <p>Konum, kişiler, kamera, mikrofon ve sağlık verisi <strong>toplanmaz</strong>.
  Reklam kimliği kullanılmaz, veriler üçüncü taraflara satılmaz.</p>
</div>

<div class="card">
  <h2>Kullanım amacı</h2>
  <p>Veriler yalnızca duyuru akışını kişiselleştirmek ve seçtiğiniz federasyonların
  duyurularında bildirim göndermek için kullanılır.</p>
</div>

<div class="card">
  <h2>İçerik kaynağı</h2>
  <p>Uygulamadaki duyurular, Türkiye'deki spor federasyonlarının <strong>herkese açık</strong>
  resmî web sitelerinden derlenir. Her duyuruda kaynak federasyon adı ve orijinal bağlantı
  gösterilir; içeriğin resmî ve bağlayıcı hâli ilgili federasyonun kendi sitesindedir.
  {APP_NAME} bu federasyonlarla resmî bir bağlantısı olmayan bağımsız bir uygulamadır.</p>
</div>

<div class="card">
  <h2>Haklarınız (KVKK / GDPR)</h2>
  <p>Verilerinize erişme, düzeltme ve silme hakkınız vardır. Hesap silme işlemini
  uygulama içinden veya <a href="/hesap-silme">hesap silme sayfasından</a> yapabilirsiniz.</p>
</div>"""
    return _layout("Gizlilik Politikası", body)


def support_html() -> str:
    body = f"""
<h1>Destek</h1>
<div class="card">
  <p>Soru, hata bildirimi ve içerik düzeltme talepleri için
  <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a> adresine yazabilirsiniz.</p>
  <h2>Sık sorulanlar</h2>
  <ul>
    <li><strong>Duyurular ne sıklıkla güncellenir?</strong> Federasyon siteleri yarım saatte bir taranır.</li>
    <li><strong>Bir duyuru eksik görünüyor.</strong> Kaynak sitedeki değişiklikleri bize bildirin, kaynağı güncelleyelim.</li>
    <li><strong>Federasyon ekletmek istiyorum.</strong> Federasyon adı ve site adresini gönderin.</li>
  </ul>
</div>
<p><a href="/gizlilik">Gizlilik Politikası</a> · <a href="/hesap-silme">Hesap Silme</a></p>"""
    return _layout("Destek", body)


def index_html(base_url: str, support_email: str) -> str:
    body = f"""
<h1>{APP_NAME}</h1>
<p>Türkiye'deki spor federasyonlarının duyurularını tek akışta toplayan servis.</p>
<div class="card">
  <h2>Bağlantılar</h2>
  <ul>
    <li><a href="/docs">API dokümantasyonu</a></li>
    <li><a href="/gizlilik">Gizlilik Politikası</a></li>
    <li><a href="/hesap-silme">Hesap Silme</a></li>
    <li><a href="/destek">Destek</a></li>
    <li><a href="/v1/status/sources">Kaynak sağlık durumu</a></li>
  </ul>
</div>"""
    return _layout("Ana Sayfa", body)
