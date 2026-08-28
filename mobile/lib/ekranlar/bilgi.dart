import 'package:flutter/material.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import 'belge_goruntule.dart';

/// Bilgi Deposu: 65 federasyonun mevzuatı ve oyun kuralları tek yerde.
///
/// İki ayrı kategori var — talimat/yönetmelik ve oyun kuralları — çünkü
/// antrenörün aradığı şey genelde ikisinden biri, karışık liste işe yaramıyor.
///
/// Belgeler federasyona göre kümelenir ve kümeler kapalı açılır: 1.400 belge
/// düz liste hâlinde okunmuyordu. Arama yapılınca eşleşen kümeler kendiliğinden
/// açılır.
///
/// Belgeler her gün parmak iziyle denetleniyor; son kontrolde değişen
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

  /// Elle açılmış kümeler. Arama sırasında hepsi zaten açık sayılır.
  final Set<String> _acik = {};

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

  bool get _araniyor => _sorgu.trim().length >= 2;

  /// Türkçe I/i çiftini elle katlıyoruz; aksi hâlde "İZİN" ile "izin"
  /// eşleşmiyor.
  static String _kucult(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  List<_Grup> _gruplar({required bool oyunKurali}) {
    final d = _depo;
    if (d == null) return const [];
    final k = _kucult(_sorgu.trim());

    final gruplar = <_Grup>[];
    for (final kut in d.kutuphaneler) {
      // Kisaltmalar benzersiz degil: Aticilik ve Atletizm ikisi de "TAF",
      // Badminton ve Bilardo ikisi de "TBF". Tam ad yaziliyor.
      final ad = kut.federasyonAdi.isNotEmpty ? kut.federasyonAdi : kut.federasyon;
      final fedUyuyor = _araniyor && _kucult(ad).contains(k);

      final belgeler = <Belge>[];
      for (final b in kut.belgeler) {
        if (oyunKuraliMi(b) != oyunKurali) continue;
        // Federasyon adı eşleşiyorsa o kümenin tamamı gösterilir
        if (_araniyor && !fedUyuyor && !_kucult(b.baslik).contains(k)) continue;
        belgeler.add(b);
      }
      if (belgeler.isEmpty) continue;

      // Antrenoru ilgilendirenler kumenin basinda
      belgeler.sort((a, b) =>
          (a.antrenorIcin ? 0 : 1) - (b.antrenorIcin ? 0 : 1));

      gruplar.add(_Grup(
        ad: ad,
        slug: kut.federasyon,
        degisti: d.degisenler.contains(kut.federasyon),
        belgeler: belgeler,
      ));
    }
    gruplar.sort((a, b) => a.ad.compareTo(b.ad));
    return gruplar;
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
              _kumeler(_gruplar(oyunKurali: false), 'talimat ve yönetmelik'),
              _kumeler(_gruplar(oyunKurali: true), 'oyun kuralı'),
            ],
          ),
        ),
    ]);
  }

  Widget _kumeler(List<_Grup> gruplar, String tur) {
    if (gruplar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _araniyor
                ? 'Aramanıza uyan $tur belgesi yok.'
                : 'Henüz $tur belgesi indirilmedi.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Renkler.metinIkincil, fontSize: 13.5, height: 1.5),
          ),
        ),
      );
    }

    final toplam =
        gruplar.fold<int>(0, (t, g) => t + g.belgeler.length);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 10, Olcu.kenar, 28),
      itemCount: gruplar.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                '${gruplar.length} federasyon · $toplam belge',
                style: Yazi.kucuk),
          );
        }
        final g = gruplar[i - 1];
        return _Kume(
          grup: g,
          acik: _araniyor || _acik.contains(g.slug),
          degistir: () => setState(() {
            _acik.contains(g.slug) ? _acik.remove(g.slug) : _acik.add(g.slug);
          }),
        );
      },
    );
  }
}

class _Grup {
  final String ad;
  final String slug;
  final bool degisti;
  final List<Belge> belgeler;

  const _Grup({
    required this.ad,
    required this.slug,
    required this.degisti,
    required this.belgeler,
  });

  int get antrenorSayisi => belgeler.where((b) => b.antrenorIcin).length;
}

/// Federasyon kümesi: başlığa dokununca belgeler açılır.
class _Kume extends StatelessWidget {
  final _Grup grup;
  final bool acik;
  final VoidCallback degistir;

  const _Kume({
    required this.grup,
    required this.acik,
    required this.degistir,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Renkler.yuzey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: acik ? Renkler.cizgiParlak : Renkler.cizgi),
        ),
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: degistir,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Icon(
                    acik ? Icons.folder_open : Icons.folder_outlined,
                    size: 19,
                    color: Renkler.mevzuat,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(grup.ad,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Yazi.kartBaslik),
                          ),
                          if (grup.degisti) ...[
                            const SizedBox(width: 7),
                            _Rozet(
                                metin: 'GÜNCELLENDİ', renk: Renkler.takvim),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          grup.antrenorSayisi > 0
                              ? '${grup.belgeler.length} belge · '
                                  '${grup.antrenorSayisi} antrenör belgesi'
                              : '${grup.belgeler.length} belge',
                          style: Yazi.kucuk,
                        ),
                      ],
                    ),
                  ),
                  Icon(acik ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: Renkler.metinSolgun),
                ]),
              ),
            ),
          ),
          if (acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: [
                  for (final b in grup.belgeler)
                    _BelgeSatiri(belge: b, federasyon: grup.ad),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

class _BelgeSatiri extends StatelessWidget {
  final Belge belge;
  final String federasyon;
  const _BelgeSatiri({required this.belge, required this.federasyon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => BelgeGoruntule.ac(context, belge, federasyon),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  belge.tur == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                  size: 16,
                  color:
                      belge.antrenorIcin ? Renkler.kurs : Renkler.metinSolgun,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  belge.baslik,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Renkler.metinIkincil,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight:
                        belge.antrenorIcin ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new, size: 14, color: Renkler.metinSolgun),
            ],
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
