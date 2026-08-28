import 'package:flutter/material.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Bilgi Deposu: 65 federasyonun mevzuatı ve oyun kuralları tek yerde.
///
/// İki ayrı kategori var — talimat/yönetmelik ve oyun kuralları — çünkü
/// antrenörün aradığı şey genelde ikisinden biri, karışık liste işe yaramıyor.
/// Belgeler günlük olarak parmak iziyle denetleniyor; son kontrolde değişen
/// federasyonlar "güncellendi" rozetiyle işaretli.
class BilgiEkrani extends StatefulWidget {
  final Veri veri;
  const BilgiEkrani({super.key, required this.veri});

  @override
  State<BilgiEkrani> createState() => _BilgiEkraniDurumu();
}

class _BilgiEkraniDurumu extends State<BilgiEkrani>
    with SingleTickerProviderStateMixin {
  late final TabController _sekme = TabController(length: 2, vsync: this);
  final _arama = TextEditingController();

  MevzuatDeposu? _depo;
  String _sorgu = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _sekme.dispose();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final d = await widget.veri.mevzuatDeposu();
    if (mounted) setState(() => _depo = d);
  }

  /// Türkçe I/i çiftini elle katlıyoruz; aksi hâlde "İZİN" ile "izin"
  /// eşleşmiyor.
  static String _kucult(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  List<_Kayit> _liste({required bool oyunKurali}) {
    final d = _depo;
    if (d == null) return const [];
    final k = _kucult(_sorgu.trim());

    final cikti = <_Kayit>[];
    for (final kut in d.kutuphaneler) {
      final ad = kut.kisaAd.isNotEmpty ? kut.kisaAd : kut.federasyonAdi;
      for (final b in kut.belgeler) {
        if (oyunKuraliMi(b) != oyunKurali) continue;
        if (k.length >= 2 &&
            !_kucult('${b.baslik} $ad').contains(k)) {
          continue;
        }
        cikti.add(_Kayit(
          belge: b,
          federasyon: ad,
          slug: kut.federasyon,
          degisti: d.degisenler.contains(kut.federasyon),
        ));
      }
    }
    // Antrenoru ilgilendirenler basa, sonra federasyon adina gore
    cikti.sort((a, b) {
      final fark = (a.belge.antrenorIcin ? 0 : 1) - (b.belge.antrenorIcin ? 0 : 1);
      if (fark != 0) return fark;
      return a.federasyon.compareTo(b.federasyon);
    });
    return cikti;
  }

  @override
  Widget build(BuildContext context) {
    final d = _depo;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Olcu.kenar, 4, Olcu.kenar, 10),
        child: TextField(
          controller: _arama,
          style: TextStyle(color: Renkler.metin, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Belge veya federasyon ara',
            hintStyle: TextStyle(color: Renkler.metinSolgun, fontSize: 14.5),
            prefixIcon:
                Icon(Icons.search, size: 20, color: Renkler.metinSolgun),
            suffixIcon: _sorgu.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: Renkler.metinSolgun),
                    onPressed: () {
                      _arama.clear();
                      setState(() => _sorgu = '');
                    },
                  ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Renkler.cizgi),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Renkler.cizgi),
            ),
          ),
          onChanged: (v) => setState(() => _sorgu = v),
        ),
      ),
      TabBar(
        controller: _sekme,
        labelColor: Renkler.metin,
        unselectedLabelColor: Renkler.metinSolgun,
        indicatorColor: Renkler.mevzuat,
        tabs: const [
          Tab(text: 'Mevzuat'),
          Tab(text: 'Oyun kuralları'),
        ],
      ),
      if (d == null)
        const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else
        Expanded(
          child: TabBarView(
            controller: _sekme,
            children: [
              _belgeler(_liste(oyunKurali: false), 'talimat ve yönetmelik'),
              _belgeler(_liste(oyunKurali: true), 'oyun kuralı'),
            ],
          ),
        ),
    ]);
  }

  Widget _belgeler(List<_Kayit> kayitlar, String tur) {
    if (kayitlar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _sorgu.trim().length >= 2
                ? 'Aramanıza uyan $tur belgesi yok.'
                : 'Henüz $tur belgesi indirilmedi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Renkler.metinIkincil, fontSize: 13.5, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 10, Olcu.kenar, 28),
      itemCount: kayitlar.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${kayitlar.length} belge', style: Yazi.kucuk),
          );
        }
        return _BelgeSatiri(kayit: kayitlar[i - 1]);
      },
    );
  }
}

class _Kayit {
  final Belge belge;
  final String federasyon;
  final String slug;
  final bool degisti;

  const _Kayit({
    required this.belge,
    required this.federasyon,
    required this.slug,
    required this.degisti,
  });
}

class _BelgeSatiri extends StatelessWidget {
  final _Kayit kayit;
  const _BelgeSatiri({required this.kayit});

  @override
  Widget build(BuildContext context) {
    final b = kayit.belge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Renkler.yuzey,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Baglanti.ac(context, b.url),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Renkler.cizgi),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    b.tur == 'pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.description_outlined,
                    size: 18,
                    color: b.antrenorIcin ? Renkler.kurs : Renkler.mevzuat,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.baslik,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Yazi.kartBaslik),
                      const SizedBox(height: 4),
                      Row(children: [
                        Flexible(
                          child: Text(kayit.federasyon,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Yazi.kucuk),
                        ),
                        if (b.antrenorIcin) ...[
                          const SizedBox(width: 8),
                          _Rozet(metin: 'ANTRENÖR', renk: Renkler.kurs),
                        ],
                        if (kayit.degisti) ...[
                          const SizedBox(width: 6),
                          _Rozet(metin: 'GÜNCELLENDİ', renk: Renkler.takvim),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new, size: 15, color: Renkler.metinSolgun),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  final String metin;
  final Color renk;
  const _Rozet({required this.metin, required this.renk});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: renk.withValues(alpha: 0.32)),
        ),
        child: Text(metin,
            style: TextStyle(
                color: renk, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}
