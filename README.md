# Antrenör

Türkiye'deki spor federasyonlarının duyurularını tek akışta toplayan mobil uygulama ve
onu besleyen açık veri hattı. Antrenörlerin **kurs, vize, terfi ve seminer** duyurularını
kaçırmaması için yapıldı.

66 kurum (bağımsız spor federasyonları + GSB, Spor Genel Müdürlüğü, TMOK, TMPK, Spor Toto)
saatte bir taranır; sonuç JSON olarak GitHub Pages üzerinden yayınlanır.

## Nasıl çalışıyor

```
Federasyon siteleri ──► GitHub Actions (saatlik tarama) ──► docs/api/v1/*.json
                                    │                              │
                                    └──► Firebase ── bildirim      └──► GitHub Pages ──► uygulama
```

Sunucu yok: tarama GitHub Actions'ta çalışır, veri depoda durur, dağıtımı Pages'in CDN'i yapar.

## Veri uçları

| Dosya | İçerik |
|---|---|
| `api/v1/meta.json` | Sürüm, son güncelleme, sayılar — uygulama önce bunu okur |
| `api/v1/federations.json` | 66 kurum, branşlar, duyuru sayıları, bildirim konusu |
| `api/v1/feed.json` | Son 300 duyuru |
| `api/v1/announcements.json` | Tüm duyurular (tam senkron) |
| `api/v1/fed/<slug>.json` | Federasyon bazında son 60 |
| `api/v1/tag/antrenor.json` | Antrenörlük duyuruları (kurs, vize, terfi) |
| `api/v1/category/kurs.json` | Kategori bazında |

Her kayıt: `id, federation, title, url, summary, image, category, tags, published_at`.
İçeriğin resmî hâli daima kaynak federasyonun sitesindedir; `url` alanı oraya gider.

## Depo düzeni

```
backend/           tarama motoru, sınıflandırma, isteğe bağlı FastAPI sunucusu
  app/scraper/     kaynak keşfi, çıkarım, adaptörler
  scripts/         ci_update.py (Actions), scrape.py, discover_sources.py …
  deploy/          kendi sunucunuzda çalıştırmak isterseniz
docs/              yayınlanan JSON + gizlilik/destek sayfaları (GitHub Pages)
.github/workflows/ saatlik tarama, haftalık kaynak keşfi
```

## Yerelde çalıştırma

```bash
pip install -r backend/requirements.txt
python -m playwright install chromium

python backend/scripts/ci_update.py      # tara ve docs/ altına yaz
python backend/scripts/build_site.py     # statik sayfaları üret
```

Klasik sunucu (REST API + veritabanı) isterseniz: [backend/README.md](backend/README.md)

## Kaynak ve sorumluluk

Duyurular federasyonların herkese açık resmî sayfalarından derlenir; tam metin
kopyalanmaz, özet gösterilip kaynağa bağlantı verilir. Tarama saatte bir çalışır,
eşzamanlılık düşük tutulur ve istekler `From`/`X-Contact` başlıklarıyla kimlik bildirir.
Taranan 66 sitenin hiçbirinin `robots.txt` dosyası bu erişimi kısıtlamıyor
(`backend/scripts/robots_audit.py`).

Antrenör, federasyonlarla resmî bir bağlantısı olmayan bağımsız bir uygulamadır.
