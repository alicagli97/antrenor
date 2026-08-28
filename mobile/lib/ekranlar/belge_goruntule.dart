import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/belge_deposu.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';

/// Mevzuat belgesini uygulamanın içinde açar.
///
/// Belge federasyonun kendi sunucusundan indirilip cihaza yazılır; ikinci
/// açılışta ağa çıkılmaz, uçak modunda da açılır. Tarayıcıya çıkmak yalnızca
/// PDF olmayan belgelerde ve indirme başarısız olduğunda kalıyor.
class BelgeGoruntule extends StatefulWidget {
  final Belge belge;
  final String federasyon;

  const BelgeGoruntule({
    super.key,
    required this.belge,
    required this.federasyon,
  });

  /// PDF'yi uygulama içinde açar; diğer türlerde kaynağa yönlendirir.
  static Future<void> ac(
      BuildContext context, Belge belge, String federasyon) async {
    if (belge.tur != 'pdf') {
      await Baglanti.ac(context, belge.url);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BelgeGoruntule(belge: belge, federasyon: federasyon),
    ));
  }

  @override
  State<BelgeGoruntule> createState() => _BelgeGoruntuleDurumu();
}

class _BelgeGoruntuleDurumu extends State<BelgeGoruntule> {
  File? _dosya;
  String? _hata;
  double _ilerleme = 0;
  bool _yereldenGeldi = false;

  int _sayfa = 0;
  int _toplamSayfa = 0;

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    setState(() {
      _hata = null;
      _ilerleme = 0;
    });
    final yerel = await BelgeDeposu.yereldenAl(widget.belge.url);
    if (yerel != null) {
      if (!mounted) return;
      setState(() {
        _dosya = yerel;
        _yereldenGeldi = true;
      });
      return;
    }
    try {
      final f = await BelgeDeposu.getir(
        widget.belge.url,
        ilerleme: (o) => mounted ? setState(() => _ilerleme = o) : null,
      );
      if (!mounted) return;
      setState(() => _dosya = f);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.belge.baslik,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            Text(
              _toplamSayfa > 0
                  ? '${widget.federasyon} · ${_sayfa + 1}/$_toplamSayfa'
                  : widget.federasyon,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Renkler.metinSolgun),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Kaynakta aç',
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => Baglanti.ac(context, widget.belge.url),
          ),
        ],
      ),
      body: _govde(),
      bottomNavigationBar: _dosya != null && _yereldenGeldi
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              color: Renkler.yuzey,
              child: Text('Bu belge cihazınızda kayıtlı, internet gerekmiyor',
                  textAlign: TextAlign.center, style: Yazi.kucuk),
            )
          : null,
    );
  }

  Widget _govde() {
    final hata = _hata;
    if (hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 40, color: Renkler.metinSolgun),
              const SizedBox(height: 14),
              Text('Belge açılamadı',
                  style: Yazi.baslik, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(hata,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Renkler.metinIkincil,
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                      onPressed: _getir, child: const Text('Tekrar dene')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Renkler.yuzeyYuksek,
                        foregroundColor: Renkler.metin),
                    onPressed: () => Baglanti.ac(context, widget.belge.url),
                    child: const Text('Kaynakta aç'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final f = _dosya;
    if (f == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 190,
              child: LinearProgressIndicator(
                value: _ilerleme > 0 ? _ilerleme : null,
                minHeight: 3,
                backgroundColor: Renkler.yuzeyYuksek,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _ilerleme > 0
                  ? 'Belge indiriliyor · %${(_ilerleme * 100).round()}'
                  : 'Belge indiriliyor',
              style: Yazi.kucuk,
            ),
          ],
        ),
      );
    }

    return PDFView(
      filePath: f.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: false,
      onRender: (sayfa) => mounted
          ? setState(() => _toplamSayfa = sayfa ?? 0)
          : null,
      onPageChanged: (s, t) => mounted
          ? setState(() {
              _sayfa = s ?? 0;
              _toplamSayfa = t ?? _toplamSayfa;
            })
          : null,
      onError: (e) => mounted ? setState(() => _hata = '$e') : null,
    );
  }
}
