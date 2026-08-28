import 'dart:async';

import 'package:flutter/material.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/takvime.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/erisim.dart';

/// Çevrimdışı arama.
///
/// İndirilmiş her şeyin içinde arar: duyurular, faaliyet takvimindeki
/// etkinlikler ve mevzuat belgeleri. Ağ isteği yapmaz — uçak modunda da
/// çalışır, çünkü veri zaten cihazda.
class AramaEkrani extends StatefulWidget {
  final Veri veri;
  const AramaEkrani({super.key, required this.veri});

  @override
  State<AramaEkrani> createState() => _AramaEkraniDurumu();
}

class _AramaEkraniDurumu extends State<AramaEkrani> {
  final _denetleyici = TextEditingController();
  Timer? _bekleme;
  List<AramaSonucu> _sonuclar = const [];
  bool _arandi = false;

  @override
  void dispose() {
    _bekleme?.cancel();
    _denetleyici.dispose();
    super.dispose();
  }

  /// Her tuşta aramak 3.000 kaydı boşuna tarardı; yazma durunca aranır.
  void _degisti(String s) {
    _bekleme?.cancel();
    _bekleme = Timer(const Duration(milliseconds: 250), () => _ara(s));
  }

  Future<void> _ara(String sorgu) async {
    final sonuc = await widget.veri.ara(sorgu);
    if (!mounted) return;
    setState(() {
      _sonuclar = sonuc;
      _arandi = sorgu.trim().length >= 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _denetleyici,
          autofocus: true,
          style: TextStyle(color: Renkler.metin, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Duyuru, etkinlik veya belge ara',
            hintStyle: TextStyle(color: Renkler.metinSolgun, fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: _degisti,
        ),
        actions: [
          if (_denetleyici.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: Renkler.metinIkincil),
              onPressed: () {
                _denetleyici.clear();
                setState(() {
                  _sonuclar = const [];
                  _arandi = false;
                });
              },
            ),
        ],
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (!_arandi) {
      return _Bilgi(
        simge: Icons.search,
        baslik: 'Çevrimdışı arama',
        metin: 'İndirilen duyurular, faaliyet takvimleri ve mevzuat '
            'belgeleri içinde arar. İnternet gerekmez.',
      );
    }
    if (_sonuclar.isEmpty) {
      return _Bilgi(
        simge: Icons.search_off,
        baslik: 'Sonuç yok',
        metin: 'Farklı bir kelime deneyin. Daha çok federasyonun sayfasını '
            'açtıkça arama kapsamı genişler.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: _sonuclar.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${_sonuclar.length} sonuç', style: Yazi.kucuk),
          );
        }
        return _SonucSatiri(
          sonuc: _sonuclar[i - 1],
          veri: widget.veri,
        );
      },
    );
  }
}

class _SonucSatiri extends StatelessWidget {
  final AramaSonucu sonuc;
  final Veri veri;

  const _SonucSatiri({required this.sonuc, required this.veri});

  (IconData, Color, String) get _tur => switch (sonuc.tur) {
        AramaTuru.duyuru => (Icons.campaign, Renkler.duyuru, 'Duyuru'),
        AramaTuru.etkinlik => (Icons.event, Renkler.takvim, 'Etkinlik'),
        AramaTuru.belge => (Icons.description, Renkler.mevzuat, 'Belge'),
      };

  Future<void> _ac(BuildContext context) async {
    switch (sonuc.tur) {
      case AramaTuru.duyuru:
        await duyuruyuAc(context, sonuc.duyuruKaydi!);
      case AramaTuru.belge:
        if (context.mounted) await Baglanti.ac(context, sonuc.url);
      case AramaTuru.etkinlik:
        final eklendi = await Takvime.etkinlikEkle(sonuc.etkinlikKaydi!,
            kaynak: sonuc.altBilgi);
        if (!context.mounted) return;
        if (!eklendi) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bu etkinliğin kesin tarihi yok, takvime eklenemedi'),
          ));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (simge, renk, etiket) = _tur;
    return Material(
      color: Renkler.yuzey,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _ac(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Renkler.cizgi),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(simge, size: 18, color: renk),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sonuc.baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Yazi.kartBaslik),
                  const SizedBox(height: 3),
                  Text(
                    sonuc.altBilgi.isEmpty
                        ? etiket
                        : '$etiket · ${sonuc.altBilgi}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Yazi.kucuk,
                  ),
                ],
              ),
            ),
            if (sonuc.tur == AramaTuru.etkinlik)
              Icon(Icons.event_available, size: 17, color: Renkler.metinSolgun),
          ]),
        ),
      ),
    );
  }
}

class _Bilgi extends StatelessWidget {
  final IconData simge;
  final String baslik;
  final String metin;

  const _Bilgi({required this.simge, required this.baslik, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(simge, size: 42, color: Renkler.metinSolgun),
            const SizedBox(height: 14),
            Text(baslik, style: Yazi.baslik, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(metin,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Renkler.metinIkincil, fontSize: 13.5, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
