# Marka Varlıkları

Logo ve isim değişmedi. Kaynak dosya `a1.png` (343×358 px) mağazalar için küçük
kaldığından amblem ölçülüp **vektör olarak yeniden kuruldu**; tüm boyutlar
`build_logo.py` ile üretiliyor.

```bash
python brand/build_logo.py            # tüm boyutları üret
python brand/build_logo.py --dogrula  # kaynakla piksel karşılaştırması
```

## Üretilen dosyalar

| Dosya | Boyut | Kullanım |
|---|---|---|
| `icon-1024.png` | 1024×1024 | App Store |
| `icon-512.png` | 512×512 | Play Store |
| `icon-192.png` | 192×192 | Web / PWA |
| `adaptive-foreground.png` + `adaptive-background.png` | 432×432 | Android uyarlanabilir simge |
| `logo-full-1024.png` · `logo-full-2048.png` | kare | Splash, tanıtım |
| `feature-graphic-1024x500.png` | 1024×500 | Play Store öne çıkan görsel |

## Renkler

| Rol | Kod |
|---|---|
| Zemin | `#000205` |
| Amblem — sağ yüzey | `#C6C6C6` |
| Amblem — sol yüzey | `#7D7D7D` |
| Amblem — kıvrım | `#575757` |
| Yazı | `#F3F3F3` |

## Doğruluk

Vektör model kaynakla piksel bazında karşılaştırıldı: **genel örtüşme %97.9**
(zemin %99.7, açık yüzey %95.7, orta yüzey %94.1). Amblem her çözünürlükte
keskin.

## Bilinen sınır: yazı

"ANTRENÖR" yazısı vektörleştirilmedi. Harf biçimi özgün logoya ait ve yazı tipi
elimizde yok — Windows'taki adaylarla en iyi eşleşme %43'te kaldı, yani başka
bir font kullanmak kimliği değiştirirdi. Bu yüzden yazı kaynaktan ölçekleniyor
ve 171 px genişliğindeki kaynak büyüdükçe basamaklanıyor.

Simgelerde yazı kullanılmıyor (Apple da simgede metin istemiyor), dolayısıyla
mağaza gereksinimleri bundan etkilenmiyor. Splash ve tanıtım görsellerinde
baskı kalitesi isteniyorsa **özgün logo dosyası** (AI/SVG/PSD veya yüksek
çözünürlüklü PNG) gerekir.
