import 'package:flutter/material.dart';

import '../cekirdek/hatirlatici.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import '../parcalar/erisim.dart';

/// Kaydedilen duyurular ve kurulmuş hatırlatmalar.
///
/// İkisi de tamamen cihazda durur: kayıtlar sunucudan silinse bile burada
/// kalır ve internetsiz okunur, hatırlatmalar telefonun zamanlayıcısındadır.
class KaydedilenlerEkrani extends StatefulWidget {
  final Veri veri;
  const KaydedilenlerEkrani({super.key, required this.veri});

  @override
  State<KaydedilenlerEkrani> createState() => _KaydedilenlerDurumu();
}

class _KaydedilenlerDurumu extends State<KaydedilenlerEkrani> {
  List<Duyuru> _kayitlar = const [];
  List<Hatirlatma> _hatirlatmalar = const [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final kayitlar = await widget.veri.kaydedilenler();
    final hatirlatmalar = await Hatirlatici.liste();
    if (!mounted) return;
    setState(() {
      _kayitlar = kayitlar;
      _hatirlatmalar = hatirlatmalar;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_kayitlar.isEmpty && _hatirlatmalar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 42, color: Renkler.metinSolgun),
              const SizedBox(height: 14),
              Text('Henüz kayıt yok',
                  style: Yazi.baslik, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Bir duyuruyu açıp yer imi simgesine dokunun. Kaydedilen '
                'duyurular internet olmadan da açılır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Renkler.metinIkincil, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (_hatirlatmalar.isNotEmpty) ...[
            _Baslik(
              metin: 'Hatırlatmalar',
              sayi: _hatirlatmalar.length,
            ),
            for (final h in _hatirlatmalar) ...[
              _HatirlatmaSatiri(
                hatirlatma: h,
                onIptal: () async {
                  await Hatirlatici.iptal(h.anahtar);
                  await _yukle();
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
          ],
          if (_kayitlar.isNotEmpty) ...[
            _Baslik(metin: 'Kaydedilen duyurular', sayi: _kayitlar.length),
            for (final d in _kayitlar)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DuyuruKarti(
                  duyuru: d,
                  takipte: widget.veri.takipEdilen.contains(d.federasyon),
                  onTap: () async {
                    await duyuruyuAc(context, d);
                    await _yukle();
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  final int sayi;
  const _Baslik({required this.metin, required this.sayi});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(children: [
          Text(metin, style: Yazi.baslik),
          const SizedBox(width: 8),
          Text('$sayi', style: Yazi.kucuk),
        ]),
      );
}

class _HatirlatmaSatiri extends StatelessWidget {
  final Hatirlatma hatirlatma;
  final VoidCallback onIptal;

  const _HatirlatmaSatiri({required this.hatirlatma, required this.onIptal});

  @override
  Widget build(BuildContext context) {
    final kalan = hatirlatma.ne.difference(DateTime.now());
    final ne = kalan.inDays >= 1
        ? '${kalan.inDays} gün sonra'
        : kalan.inHours >= 1
            ? '${kalan.inHours} saat sonra'
            : '${kalan.inMinutes} dakika sonra';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Renkler.yuzey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Renkler.cizgi),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active, size: 18, color: Renkler.kurs),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hatirlatma.baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Yazi.kartBaslik),
              const SizedBox(height: 3),
              Text('${_tarihSaat(hatirlatma.ne)} · $ne', style: Yazi.kucuk),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Hatırlatmayı kaldır',
          icon: Icon(Icons.close, size: 18, color: Renkler.metinSolgun),
          onPressed: onIptal,
        ),
      ]),
    );
  }

  static String _tarihSaat(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}'
      '.${t.year} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
