import 'package:flutter/material.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/takvime.dart';
import '../cekirdek/tema.dart';
import 'belge_goruntule.dart';
import '../cekirdek/veri.dart';
import '../parcalar/bildirim_istegi.dart';
import '../parcalar/duyuru_karti.dart';
import '../parcalar/erisim.dart';

/// Bir federasyonun her şeyi: duyurular, faaliyet takvimi, mevzuat ve
/// oyun kuralları. Mevzuat belgeleri başlığına göre ikiye ayrılır —
/// "kural" geçenler oyun kuralları, diğerleri talimat/yönetmelik.
class FederasyonDetay extends StatefulWidget {
  final Veri veri;
  final Federasyon federasyon;
  const FederasyonDetay(
      {super.key, required this.veri, required this.federasyon});

  @override
  State<FederasyonDetay> createState() => _FederasyonDetayDurumu();
}

class _FederasyonDetayDurumu extends State<FederasyonDetay> {
  List<Duyuru> _duyurular = const [];
  Takvim? _takvim;
  MevzuatKutuphanesi? _mevzuat;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final slug = widget.federasyon.slug;
    final sonuc = await Future.wait([
      widget.veri.fedDuyurulari(slug),
      widget.veri.fedTakvimi(slug),
      widget.veri.fedMevzuati(slug),
    ]);
    if (!mounted) return;
    setState(() {
      _duyurular = sonuc[0] as List<Duyuru>;
      _takvim = sonuc[1] as Takvim?;
      _mevzuat = sonuc[2] as MevzuatKutuphanesi?;
      _yukleniyor = false;
    });
  }

  bool _oyunKurali(Belge b) {
    final t = b.baslik.toLowerCase();
    return t.contains('kural') || t.contains('oyun');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.federasyon;
    final takipte = widget.veri.takipEdilen.contains(f.slug);
    // Web sayfasi baglantilarini disarida birakiyoruz; burasi belge listesi
    final belgeler = (_mevzuat?.belgeler ?? const <Belge>[])
        .where(belgeDosyasiMi)
        .toList();
    final kurallar = belgeler.where(_oyunKurali).toList();
    final talimatlar = belgeler.where((b) => !_oyunKurali(b)).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          // Etiket kisa ve okunakli, ama resmi ad da gorunsun
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.etiket, style: const TextStyle(fontSize: 17)),
              Text(f.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: Renkler.metinSolgun)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(takipte ? Icons.star : Icons.star_border,
                  color: takipte ? Renkler.kurs : Renkler.metinIkincil),
              tooltip: takipte ? 'Takibi bırak' : 'Takip et',
              onPressed: () async {
                final yeniTakip = !takipte;
                // Takip sınırı yalnızca ekleme için geçerli
                if (yeniTakip &&
                    !await takipEklenebilirMi(context, widget.veri)) {
                  return;
                }
                await widget.veri.takibiDegistir(f.slug);
                if (!mounted) return;
                setState(() {});
                if (yeniTakip && context.mounted) {
                  await bildirimIzniSor(context, widget.veri);
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.public, color: Renkler.metinIkincil),
              tooltip: 'Resmî site',
              onPressed: () => Baglanti.ac(context, f.site),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Renkler.metin,
            unselectedLabelColor: Renkler.metinSolgun,
            indicatorColor: Renkler.amblemAcik,
            dividerColor: Renkler.cizgi,
            labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Duyurular'),
              Tab(text: 'Takvim'),
              Tab(text: 'Mevzuat'),
              Tab(text: 'Oyun kuralları'),
            ],
          ),
        ),
        body: _yukleniyor
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : TabBarView(
                children: [
                  _duyuruListesi(),
                  _takvimBolumu(),
                  _belgeListesi(talimatlar, 'Bu federasyonun mevzuatı bulunamadı'),
                  _belgeListesi(kurallar, 'Oyun kuralları belgesi bulunamadı'),
                ],
              ),
      ),
    );
  }

  Widget _duyuruListesi() {
    if (_duyurular.isEmpty) return const _Bos('Duyuru bulunamadı');
    return ListView.builder(
      itemCount: _duyurular.length,
      itemBuilder: (_, i) => DuyuruKarti(
        duyuru: _duyurular[i],
        onTap: () => duyuruyuAc(context, _duyurular[i]),
      ),
    );
  }

  Widget _takvimBolumu() {
    final t = _takvim;
    if (t == null) return const _Bos('Faaliyet takvimi bulunamadı');
    const aylar = [
      'OCA','ŞUB','MAR','NİS','MAY','HAZ','TEM','AĞU','EYL','EKİ','KAS','ARA'
    ];
    final tarihliler = t.etkinlikler.where((e) => e.tarih != null).toList()
      ..sort((a, b) => a.tarih!.compareTo(b.tarih!));

    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.description_outlined,
              color: Renkler.metinIkincil),
          title: Text('Kaynak takvim belgesi',
              style: Yazi.govde.copyWith(color: Renkler.metin, fontSize: 15)),
          subtitle: Text(
              '${t.tur.toUpperCase()}${t.etkinlikSayisi > 0 ? " · ${t.etkinlikSayisi} faaliyet" : ""}',
              style:
                  Yazi.kucuk),
          trailing: Icon(Icons.open_in_new,
              size: 16, color: Renkler.metinSolgun),
          onTap: () => Baglanti.ac(context, t.url),
        ),
        const Divider(height: 1),
        if (tarihliler.isEmpty)
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
                'Takvim belgeden okunamadı; kaynağı açarak görüntüleyebilirsiniz.',
                style: Yazi.govde),
          )
        else
          ...tarihliler.map((e) => Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Renkler.cizgi)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(children: [
                        Text('${e.tarih!.day}',
                            style: TextStyle(
                                color: Renkler.takvim,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(aylar[e.tarih!.month - 1],
                            style: TextStyle(
                                color: Renkler.metinSolgun, fontSize: 10.5)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.ad,
                              style: TextStyle(
                                  color: Renkler.metin,
                                  fontSize: 14,
                                  height: 1.3)),
                          if (e.yer.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(e.yer,
                                  style: TextStyle(
                                      color: Renkler.metinSolgun,
                                      fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Telefon takvimine ekle',
                      icon: Icon(Icons.event_available,
                          size: 19, color: Renkler.metinSolgun),
                      onPressed: () => _takvimeEkle(e),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  /// Etkinliği telefonun kendi takvimine yazar; onay sistem ekranında verilir.
  Future<void> _takvimeEkle(Etkinlik e) async {
    final eklendi =
        await Takvime.etkinlikEkle(e, kaynak: widget.federasyon.ad);
    if (!mounted) return;
    if (!eklendi) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Takvim uygulaması açılamadı'),
      ));
    }
  }

  Widget _belgeListesi(List<Belge> belgeler, String bosMesaj) {
    if (belgeler.isEmpty) return _Bos(bosMesaj);
    return ListView.builder(
      itemCount: belgeler.length,
      itemBuilder: (_, i) {
        final b = belgeler[i];
        return ListTile(
          leading: Icon(
            b.tur == 'pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
            size: 20,
            color: b.antrenorIcin ? Renkler.kurs : Renkler.metinSolgun,
          ),
          title: Text(b.baslik,
              style: TextStyle(
                  color: Renkler.metinIkincil, fontSize: 13.5, height: 1.3)),
          trailing: Icon(
              b.tur == 'pdf' ? Icons.chevron_right : Icons.open_in_new,
              size: b.tur == 'pdf' ? 18 : 15,
              color: Renkler.metinSolgun),
          onTap: () =>
              BelgeGoruntule.ac(context, b, widget.federasyon.ad),
        );
      },
    );
  }
}

class _Bos extends StatelessWidget {
  final String mesaj;
  const _Bos(this.mesaj);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(mesaj,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Renkler.metinSolgun, fontSize: 13.5, height: 1.4)),
        ),
      );
}
