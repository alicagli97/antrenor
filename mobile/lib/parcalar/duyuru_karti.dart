import 'package:flutter/material.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';

/// Akıştaki duyuru kartı. Federasyon rozeti, kategori etiketi ve zaman
/// tek bakışta okunur; dokununca hafifçe içeri basılır.
class DuyuruKarti extends StatefulWidget {
  final Duyuru duyuru;
  final bool takipte;
  final VoidCallback? onTap;

  const DuyuruKarti({
    super.key,
    required this.duyuru,
    this.takipte = false,
    this.onTap,
  });

  @override
  State<DuyuruKarti> createState() => _DuyuruKartiDurumu();
}

class _DuyuruKartiDurumu extends State<DuyuruKarti> {
  bool _basili = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.duyuru;
    final renk = Renkler.kategoriRengi(d.kategori);
    final fedRenk = Renkler.federasyonRengi(d.federasyon);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Olcu.kenar, 0, Olcu.kenar, Olcu.kartArasi),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _basili = true),
        onTapCancel: () => setState(() => _basili = false),
        onTapUp: (_) => setState(() => _basili = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _basili ? 0.985 : 1,
          duration: const Duration(milliseconds: 110),
          child: Container(
            decoration: kartYuzeyi(vurgu: renk, basili: _basili),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FederasyonRozeti(slug: d.federasyon, ad: d.etiketAdi),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(d.etiketAdi,
                                    overflow: TextOverflow.ellipsis,
                                    style: Yazi.govde.copyWith(
                                        color: Renkler.metinIkincil,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5)),
                              ),
                              if (widget.takipte) ...[
                                const SizedBox(width: 5),
                                Icon(Icons.star_rounded,
                                    size: 13, color: fedRenk),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(_zaman(d.yayinTarihi), style: Yazi.kucuk),
                        ],
                      ),
                    ),
                    _KategoriEtiketi(kategori: d.kategori, renk: renk),
                  ],
                ),
                const SizedBox(height: 12),
                Text(d.baslik,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Yazi.kartBaslik),
                if (d.ozet.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(d.ozet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Yazi.govde.copyWith(fontSize: 13.5)),
                ],
                if (d.antrenorIcin) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Renkler.kurs.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(Olcu.rozetYaricap),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_rounded,
                                size: 12, color: Renkler.kurs),
                            const SizedBox(width: 5),
                            Text('ANTRENÖR',
                                style: Yazi.etiket
                                    .copyWith(color: Renkler.kurs, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _zaman(DateTime? t) {
    if (t == null) return '';
    final fark = DateTime.now().difference(t);
    if (fark.inMinutes < 60) return '${fark.inMinutes} dakika önce';
    if (fark.inHours < 24) return '${fark.inHours} saat önce';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    const aylar = [
      'Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'
    ];
    return '${t.day} ${aylar[t.month - 1]} ${t.year}';
  }
}

/// Federasyon rozeti: adın baş harfleri, federasyona özgü sabit renkte.
class FederasyonRozeti extends StatelessWidget {
  final String slug;
  final String ad;
  final double boyut;

  const FederasyonRozeti(
      {super.key, required this.slug, required this.ad, this.boyut = 38});

  @override
  Widget build(BuildContext context) {
    final renk = Renkler.federasyonRengi(slug);
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            renk.withValues(alpha: 0.28),
            renk.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(boyut * 0.32),
        border: Border.all(color: renk.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        _basHarfler(ad),
        style: TextStyle(
          fontFamily: Yazi.aile,
          fontSize: boyut * 0.30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: renk,
        ),
      ),
    );
  }

  /// Tek kelimelik adlarda üç harf kullanılıyor: "Atletizm" ve "Atıcılık"
  /// iki harfte ("AT") ayırt edilemiyordu.
  static String _basHarfler(String ad) {
    final parcalar = ad
        .split(RegExp(r'[\s&·]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parcalar.isEmpty) return '?';
    if (parcalar.length == 1) {
      final p = parcalar.first;
      return (p.length >= 3 ? p.substring(0, 3) : p).toUpperCase();
    }
    return (parcalar[0][0] + parcalar[1][0]).toUpperCase();
  }
}

class _KategoriEtiketi extends StatelessWidget {
  final String kategori;
  final Color renk;
  const _KategoriEtiketi({required this.kategori, required this.renk});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(Olcu.rozetYaricap),
          border: Border.all(color: renk.withValues(alpha: 0.26)),
        ),
        child: Text(Renkler.kategoriAdi(kategori).toUpperCase(),
            style: Yazi.etiket.copyWith(color: renk, fontSize: 9.5)),
      );
}
