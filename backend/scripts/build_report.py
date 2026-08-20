# -*- coding: utf-8 -*-
"""coverage.json'dan paylasilabilir HTML rapor uretir."""
import json
import pathlib
import sys
from collections import Counter
from datetime import datetime

BASE = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else BASE / "data" / "rapor.html"

data = json.loads((BASE / "data" / "coverage.json").read_text(encoding="utf-8"))
rows = sorted(data["federasyonlar"], key=lambda r: (-r["duyuru"], r["ad"]))
cats = data["kategoriler"]
kinds = Counter(r["kaynak_turu"] for r in rows)
max_count = max(r["duyuru"] for r in rows) or 1

KIND_LABEL = {"wp_json": "WordPress API", "rss": "RSS", "html": "HTML liste",
              "render": "Tarayıcı render", "adapter": "Özel adaptör", "-": "yok"}

def esc(s: str) -> str:
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

table_rows = []
for r in rows:
    ok = r["duyuru"] > 0
    bar = round(100 * r["duyuru"] / max_count)
    note = f'<div class="note">{esc(r["not"])}</div>' if r["not"] else ""
    table_rows.append(f"""<tr class="{'' if ok else 'row-off'}">
  <td class="fed"><a href="{esc(r['site'])}" target="_blank" rel="noopener">{esc(r['ad'])}</a>{note}</td>
  <td><span class="chip chip-{r['kaynak_turu'].replace('-','none')}">{KIND_LABEL.get(r['kaynak_turu'], r['kaynak_turu'])}</span></td>
  <td class="num">{r['duyuru']}<span class="bar" style="--w:{bar}%"></span></td>
  <td class="date">{esc(r['son_tarih']) or '—'}</td>
</tr>""")

cat_labels = {"duyuru": "Genel duyuru", "kurs": "Kurs / seminer / vize", "musabaka": "Müsabaka",
              "mevzuat": "Mevzuat", "haber": "Haber"}
cat_total = sum(cats.values()) or 1
cat_bars = "".join(
    f"""<div class="catrow"><span class="catname">{cat_labels.get(k, k)}</span>
    <span class="cattrack"><span class="catfill cat-{k}" style="--w:{round(100*v/cat_total)}%"></span></span>
    <span class="catnum">{v}</span></div>"""
    for k, v in sorted(cats.items(), key=lambda x: -x[1]))

kind_rows = "".join(
    f'<li><span class="chip chip-{k.replace("-","none")}">{KIND_LABEL.get(k,k)}</span> <b>{v}</b> federasyon</li>'
    for k, v in kinds.most_common() if k != "-")

STEPS = [
    ("Keşif", "Her federasyon sitesinde duyuru listesi otomatik bulunur: WordPress API → RSS → HTML liste → gerçek tarayıcı."),
    ("Tarama", "30 dakikada bir tüm kaynaklar çekilir; site tasarımı değişirse keşif yeniden çalıştırılır."),
    ("Normalizasyon", "Başlık, tarih, özet, görsel ve kaynak bağlantısı tek biçime getirilir; Türkçe tarihler ayrıştırılır."),
    ("Sınıflandırma", "Başlıktan kategori ve etiket çıkarılır: antrenör kursu, vize, terfi, hakem, mevzuat, müsabaka."),
    ("Bildirim", "Takip edilen federasyondan yeni duyuru gelince push gönderilir; aynı duyuru iki kez düşmez."),
]
steps_html = "".join(
    f'<li><span class="stepno">{i}</span><div><h3>{t}</h3><p>{d}</p></div></li>'
    for i, (t, d) in enumerate(STEPS, 1))

html = f"""<title>Federasyon Duyuru Ağı</title>
<style>
:root {{
  --ground:#EDF0F3; --surface:#FFFFFF; --surface-2:#F6F8FA; --line:#DCE2E8;
  --ink:#101720; --ink-2:#4C5966; --ink-3:#7A8794;
  --accent:#A8201A; --steel:#21384E; --ok:#12674A; --warn:#8A5A0B;
  --shadow:0 1px 2px rgba(16,23,32,.06), 0 8px 24px -16px rgba(16,23,32,.25);
}}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --ground:#0C1015; --surface:#141A21; --surface-2:#1A222B; --line:#28323D;
    --ink:#E7ECF1; --ink-2:#A7B3BF; --ink-3:#7B8896;
    --accent:#E4635A; --steel:#8FB4D4; --ok:#4CBE92; --warn:#D9A648;
    --shadow:0 1px 2px rgba(0,0,0,.4), 0 10px 30px -18px rgba(0,0,0,.8);
  }}
}}
:root[data-theme="dark"] {{
  --ground:#0C1015; --surface:#141A21; --surface-2:#1A222B; --line:#28323D;
  --ink:#E7ECF1; --ink-2:#A7B3BF; --ink-3:#7B8896;
  --accent:#E4635A; --steel:#8FB4D4; --ok:#4CBE92; --warn:#D9A648;
  --shadow:0 1px 2px rgba(0,0,0,.4), 0 10px 30px -18px rgba(0,0,0,.8);
}}
* {{ box-sizing:border-box; }}
body {{
  margin:0; background:var(--ground); color:var(--ink);
  font:16px/1.62 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  -webkit-font-smoothing:antialiased;
}}
.wrap {{ max-width:1120px; margin:0 auto; padding:44px 22px 90px; display:flex;
        flex-direction:column; gap:34px; }}
.eyebrow {{ font:600 11px/1 ui-monospace, "Cascadia Mono", Consolas, monospace;
           letter-spacing:.16em; text-transform:uppercase; color:var(--accent); }}
h1 {{ font-size:clamp(30px,4.4vw,44px); line-height:1.08; letter-spacing:-.022em;
     margin:10px 0 8px; text-wrap:balance; font-weight:700; }}
.lede {{ font-size:18px; color:var(--ink-2); max-width:62ch; margin:0; }}
.meta {{ margin-top:14px; font:500 13px/1 ui-monospace, Consolas, monospace;
        color:var(--ink-3); display:flex; gap:18px; flex-wrap:wrap; }}
h2 {{ font-size:20px; letter-spacing:-.01em; margin:0 0 4px; }}
h3 {{ font-size:15px; margin:0 0 3px; }}
p {{ margin:0; }}
section {{ display:flex; flex-direction:column; gap:14px; }}
.card {{ background:var(--surface); border:1px solid var(--line); border-radius:12px;
        padding:20px 22px; box-shadow:var(--shadow); }}
.stats {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:14px; }}
.stat {{ background:var(--surface); border:1px solid var(--line); border-radius:12px;
        padding:18px 20px; box-shadow:var(--shadow); }}
.stat .k {{ font:600 11px/1 ui-monospace, Consolas, monospace; letter-spacing:.13em;
           text-transform:uppercase; color:var(--ink-3); }}
.stat .v {{ font:700 34px/1.05 ui-monospace, Consolas, monospace; letter-spacing:-.03em;
           margin-top:10px; font-variant-numeric:tabular-nums; }}
.stat .s {{ font-size:13px; color:var(--ink-2); margin-top:6px; }}
.stat.accent .v {{ color:var(--accent); }}
.stat.ok .v {{ color:var(--ok); }}
ol.steps {{ list-style:none; margin:0; padding:0; display:grid; gap:2px;
           grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); }}
ol.steps li {{ background:var(--surface); border:1px solid var(--line); padding:16px 18px;
              display:flex; gap:12px; align-items:flex-start; }}
ol.steps li:first-child {{ border-radius:12px 0 0 12px; }}
ol.steps li:last-child {{ border-radius:0 12px 12px 0; }}
ol.steps p {{ font-size:13.5px; color:var(--ink-2); line-height:1.5; }}
.stepno {{ flex:0 0 auto; width:24px; height:24px; border-radius:6px; background:var(--steel);
          color:var(--surface); font:700 12px/24px ui-monospace, Consolas, monospace;
          text-align:center; }}
.tablewrap {{ overflow-x:auto; border:1px solid var(--line); border-radius:12px;
             background:var(--surface); box-shadow:var(--shadow); }}
table {{ width:100%; border-collapse:collapse; min-width:640px; }}
thead th {{ position:sticky; top:0; background:var(--surface-2); text-align:left;
           font:600 11px/1 ui-monospace, Consolas, monospace; letter-spacing:.12em;
           text-transform:uppercase; color:var(--ink-3); padding:12px 16px;
           border-bottom:1px solid var(--line); }}
tbody td {{ padding:11px 16px; border-bottom:1px solid var(--line); font-size:14.5px;
           vertical-align:top; }}
tbody tr:last-child td {{ border-bottom:0; }}
tbody tr:hover td {{ background:var(--surface-2); }}
.fed a {{ color:var(--ink); text-decoration:none; border-bottom:1px solid transparent; }}
.fed a:hover, .fed a:focus-visible {{ border-bottom-color:var(--accent); color:var(--accent); }}
.note {{ font-size:12.5px; color:var(--warn); margin-top:3px; }}
td.num {{ font:600 14px/1.4 ui-monospace, Consolas, monospace; font-variant-numeric:tabular-nums;
         white-space:nowrap; position:relative; min-width:96px; }}
td.num .bar {{ display:block; height:4px; width:var(--w); background:var(--steel);
              opacity:.5; border-radius:2px; margin-top:6px; }}
td.date {{ font:400 13px/1.4 ui-monospace, Consolas, monospace; color:var(--ink-2);
          white-space:nowrap; }}
.row-off td {{ color:var(--ink-3); }}
.chip {{ display:inline-block; font:600 11px/1 ui-monospace, Consolas, monospace;
        letter-spacing:.04em; padding:5px 9px; border-radius:5px; white-space:nowrap;
        border:1px solid var(--line); background:var(--surface-2); color:var(--ink-2); }}
.chip-wp_json {{ color:var(--ok); border-color:color-mix(in srgb, var(--ok) 35%, var(--line)); }}
.chip-rss {{ color:var(--warn); border-color:color-mix(in srgb, var(--warn) 35%, var(--line)); }}
.chip-render, .chip-adapter {{ color:var(--accent);
        border-color:color-mix(in srgb, var(--accent) 35%, var(--line)); }}
.chip-none {{ opacity:.7; }}
.catrow {{ display:grid; grid-template-columns:190px 1fr 56px; align-items:center; gap:12px; }}
.cattrack {{ height:9px; background:var(--surface-2); border-radius:5px; overflow:hidden;
            border:1px solid var(--line); }}
.catfill {{ display:block; height:100%; width:var(--w); background:var(--steel); }}
.catfill.cat-kurs {{ background:var(--accent); }}
.catfill.cat-mevzuat {{ background:var(--warn); }}
.catfill.cat-musabaka {{ background:var(--ok); }}
.catname {{ font-size:14px; color:var(--ink-2); }}
.catnum {{ font:600 14px/1 ui-monospace, Consolas, monospace; text-align:right;
          font-variant-numeric:tabular-nums; }}
.two {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:14px; }}
ul.plain {{ margin:0; padding:0; list-style:none; display:flex; flex-direction:column; gap:9px;
           font-size:14.5px; color:var(--ink-2); }}
ul.plain li {{ display:flex; gap:9px; align-items:baseline; }}
ul.plain li::before {{ content:"—"; color:var(--ink-3); }}
ul.check li::before {{ content:"✓"; color:var(--ok); font-weight:700; }}
ul.todo li::before {{ content:"○"; color:var(--warn); font-weight:700; }}
footer {{ border-top:1px solid var(--line); padding-top:18px; font-size:13px; color:var(--ink-3); }}
a {{ color:var(--accent); }}
:focus-visible {{ outline:2px solid var(--accent); outline-offset:2px; }}
@media (max-width:760px) {{
  ol.steps li {{ border-radius:12px !important; }}
  .catrow {{ grid-template-columns:130px 1fr 46px; }}
}}
</style>

<div class="wrap">
<header>
  <div class="eyebrow">Antrenör · Veri Katmanı Raporu</div>
  <h1>Federasyon Duyuru Ağı</h1>
  <p class="lede">Türkiye'deki spor federasyonlarının duyuru sayfaları tarandı ve tek bir
  akışa bağlandı. Antrenörlerin kurs, vize, terfi ve seminer duyurularını kaçırmaması için
  kaynaklar otomatik keşfediliyor, 30 dakikada bir yenileniyor.</p>
  <div class="meta"><span>{datetime.now().strftime('%d.%m.%Y')}</span>
  <span>{data['toplam_federasyon']} kurum taranıyor</span>
  <span>robots.txt engeli: 0</span></div>
</header>

<section class="stats">
  <div class="stat"><div class="k">Taranan kurum</div><div class="v">{data['toplam_federasyon']}</div>
    <div class="s">Federasyonlar + GSB, SHGM, TMOK, TMPK</div></div>
  <div class="stat ok"><div class="k">Veri akan kaynak</div><div class="v">{data['veri_gelen']}</div>
    <div class="s">3 kaynak sunucu tarafından engelli</div></div>
  <div class="stat"><div class="k">Toplanan duyuru</div><div class="v">{data['toplam_duyuru']}</div>
    <div class="s">İlk taramada, tekilleştirilmiş</div></div>
  <div class="stat accent"><div class="k">Kurs / vize duyurusu</div><div class="v">{cats.get('kurs',0)}</div>
    <div class="s">Antrenörü doğrudan ilgilendiren kayıtlar</div></div>
</section>

<section>
  <h2>Hat nasıl işliyor</h2>
  <ol class="steps">{steps_html}</ol>
</section>

<section>
  <h2>İçerik dağılımı</h2>
  <div class="card" style="display:flex; flex-direction:column; gap:10px;">{cat_bars}</div>
</section>

<section>
  <h2>Kaynak türleri</h2>
  <div class="card">
    <ul class="plain">{kind_rows}</ul>
    <p style="margin-top:12px; font-size:14px; color:var(--ink-2);">Siteler tek tip değil:
    WordPress kullananlarda resmî API'den, RSS verenlerde akıştan, düz HTML sitelerde liste
    sayfasından okuyoruz. JavaScript ile çalışan veya bot doğrulaması olan sitelerde
    (Basketbol, Hentbol, Buz Hokeyi, TMOK, Briç, SHGM) gerçek tarayıcı çalıştırılıyor.</p>
  </div>
</section>

<section>
  <h2>Federasyon bazında kapsama</h2>
  <div class="tablewrap">
    <table>
      <thead><tr><th>Kurum</th><th>Kaynak</th><th>Duyuru</th><th>Son kayıt</th></tr></thead>
      <tbody>{''.join(table_rows)}</tbody>
    </table>
  </div>
</section>

<section>
  <h2>Mağaza uyumluluğu</h2>
  <div class="two">
    <div class="card">
      <h3>Hazır</h3>
      <ul class="plain check" style="margin-top:10px;">
        <li>Uygulama içi hesap silme — Apple 5.1.1(v)</li>
        <li>Web üzerinden silme talebi — Google User Data Policy</li>
        <li>Gizlilik politikası, destek ve hesap silme sayfaları</li>
        <li>Hassas izin yok: konum, kamera, mikrofon, sağlık verisi toplanmıyor</li>
        <li>Kaynak sağlık ucu — bir federasyon kesildiğinde görünür</li>
        <li>Her duyuruda federasyon adı ve orijinal bağlantı saklanıyor</li>
      </ul>
    </div>
    <div class="card">
      <h3>Arayüz ve hesap aşamasında</h3>
      <ul class="plain todo" style="margin-top:10px;">
        <li>Profil → Ayarlar → "Hesabımı Sil" ekranı</li>
        <li>App Privacy etiketleri ve Play Veri Güvenliği formu</li>
        <li>Ekran görüntüleri, 512×512 simge, feature graphic</li>
        <li>Demo hesap ve inceleme notları</li>
        <li>Sign in with Apple eklenirse token iptali (revoke)</li>
        <li>Kapalı test kanalı ile çökme oranı ölçümü</li>
      </ul>
    </div>
  </div>
</section>

<section>
  <h2>Açık kalan iki kaynak</h2>
  <div class="card">
    <ul class="plain">
      <li><b>Kick Boks Federasyonu</b> — site tüm otomatik istekleri reddediyor. Türkiye'deki
      bağlantıdan, gerçek tarayıcıyla ve tarayıcı başlıklarıyla denendi, sonuç değişmedi;
      bu bir IP konumu meselesi değil. Temiz çözüm federasyondan duyuru akışı istemek.</li>
      <li><b>Oryantiring Federasyonu</b> — duyurular sayfası bağlantısız metin kartları
      kullanıyor; bu sayfa için özel bir okuyucu yazılacak.</li>
    </ul>
    <p style="margin-top:12px; font-size:14px; color:var(--ink-2);">Tarama sırasında Milli
    Paralimpik Komitesi sitesi bir süre hata verdi, Spor Toto ise engelli görünüyordu; ikisi de
    sonraki turlarda kendiliğinden akışa girdi. Kaynaklar geçici kesintilerden kalıcı olarak
    etkilenmiyor.</p>
  </div>
</section>

<footer>Antrenör bağımsız bir duyuru toplayıcıdır; federasyonların resmî uygulaması değildir.
Duyurular kamuya açık resmî sayfalardan derlenir, özet gösterilir ve her kayıtta kaynağa
bağlantı verilir.</footer>
</div>
"""

OUT.write_text(html, encoding="utf-8")
print("rapor yazildi:", OUT, len(html), "bayt")
