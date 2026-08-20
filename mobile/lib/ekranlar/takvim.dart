import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Takvim: federasyonların faaliyet programları ve yaklaşan etkinlikler.
class TakvimEkrani extends StatefulWidget {
  final Veri veri;
  const TakvimEkrani({super.key, required this.veri});

  @override
  State<TakvimEkrani> createState() => _TakvimDurumu();
}

class _TakvimDurumu extends State<TakvimEkrani> {
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    widget.veri.takvimleriGetir().whenComplete(
        () => mounted ? setState(() => _yukleniyor = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final veri = widget.veri;
    final bugun = DateTime.now();

    // Yaklaşan etkinlikler: tüm takvimlerden tarihi bugünden sonra olanlar
    final yaklasan = <(String, Etkinlik)>[];
    for (final t in veri.takvimler) {
      for (final e in t.etkinlikler) {
        if (e.tarih != null && e.tarih!.isAfter(bugun)) {
          yaklasan.add((veri.etiketAdi(t.federasyon), e));
        }
      }
    }
    yaklasan.sort((a, b) => a.$2.tarih!.compareTo(b.$2.tarih!));

    return ListView(
      children: [
        _Baslik(
          metin: 'Yaklaşan faaliyetler',
          alt: '${veri.takvimler.length} federasyonun takvimi izleniyor',
        ),
        if (yaklasan.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Yaklaşan tarihli faaliyet bulunamadı',
                style: TextStyle(color: Renkler.metinSolgun, fontSize: 13.5)),
          ),
        ...yaklasan.take(25).map((c) => _EtkinlikSatiri(federasyon: c.$1, etkinlik: c.$2)),
        const _Baslik(metin: 'Federasyon takvimleri', alt: 'Kaynak belgeye git'),
        ...veri.takvimler.map((t) => ListTile(
              title: Text(veri.etiketAdi(t.federasyon),
                  style: const TextStyle(color: Renkler.metin, fontSize: 14.5)),
              subtitle: Text(
                  t.etkinlikSayisi > 0
                      ? '${t.etkinlikSayisi} faaliyet · ${t.tur.toUpperCase()}'
                      : t.tur.toUpperCase(),
                  style: const TextStyle(
                      color: Renkler.metinSolgun, fontSize: 12.5)),
              trailing: const Icon(Icons.open_in_new,
                  size: 16, color: Renkler.metinSolgun),
              onTap: () => launchUrl(Uri.parse(t.url),
                  mode: LaunchMode.externalApplication),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  final String alt;
  const _Baslik({required this.metin, required this.alt});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metin,
                style: const TextStyle(
                    color: Renkler.metin,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(alt,
                style: const TextStyle(
                    color: Renkler.metinSolgun, fontSize: 12.5)),
          ],
        ),
      );
}

class _EtkinlikSatiri extends StatelessWidget {
  final String federasyon;
  final Etkinlik etkinlik;
  const _EtkinlikSatiri({required this.federasyon, required this.etkinlik});

  @override
  Widget build(BuildContext context) {
    final t = etkinlik.tarih!;
    const aylar = ['OCA','ŞUB','MAR','NİS','MAY','HAZ','TEM','AĞU','EYL','EKİ','KAS','ARA'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Renkler.cizgi)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text('${t.day}',
                    style: const TextStyle(
                        color: Renkler.takvim,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                Text(aylar[t.month - 1],
                    style: const TextStyle(
                        color: Renkler.metinSolgun,
                        fontSize: 10.5,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etkinlik.ad,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Renkler.metin, fontSize: 14, height: 1.3)),
                const SizedBox(height: 3),
                Text(
                  [federasyon, if (etkinlik.yer.isNotEmpty) etkinlik.yer]
                      .join(' · '),
                  style: const TextStyle(
                      color: Renkler.metinSolgun, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
