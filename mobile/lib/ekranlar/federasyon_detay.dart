import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'duyuru_detay.dart';

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
    final belgeler = _mevzuat?.belgeler ?? const <Belge>[];
    final kurallar = belgeler.where(_oyunKurali).toList();
    final talimatlar = belgeler.where((b) => !_oyunKurali(b)).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(f.etiket, style: const TextStyle(fontSize: 17)),
          actions: [
            IconButton(
              icon: Icon(takipte ? Icons.star : Icons.star_border,
                  color: takipte ? Renkler.kurs : Renkler.metinIkincil),
              tooltip: takipte ? 'Takibi bırak' : 'Takip et',
              onPressed: () async {
                await widget.veri.takibiDegistir(f.slug);
                if (mounted) setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.public, color: Renkler.metinIkincil),
              tooltip: 'Resmî site',
              onPressed: () => launchUrl(Uri.parse(f.site),
                  mode: LaunchMode.externalApplication),
            ),
          ],
          bottom: const TabBar(
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DuyuruDetay(duyuru: _duyurular[i]))),
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
          leading: const Icon(Icons.description_outlined,
              color: Renkler.metinIkincil),
          title: const Text('Kaynak takvim belgesi',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: Text(
              '${t.tur.toUpperCase()}${t.etkinlikSayisi > 0 ? " · ${t.etkinlikSayisi} faaliyet" : ""}',
              style:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
          trailing: const Icon(Icons.open_in_new,
              size: 16, color: Renkler.metinSolgun),
          onTap: () =>
              launchUrl(Uri.parse(t.url), mode: LaunchMode.externalApplication),
        ),
        const Divider(height: 1),
        if (tarihliler.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
                'Takvim belgeden okunamadı; kaynağı açarak görüntüleyebilirsiniz.',
                style: TextStyle(color: Renkler.metinSolgun, fontSize: 13)),
          )
        else
          ...tarihliler.map((e) => Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Renkler.cizgi)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(children: [
                        Text('${e.tarih!.day}',
                            style: const TextStyle(
                                color: Renkler.takvim,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(aylar[e.tarih!.month - 1],
                            style: const TextStyle(
                                color: Renkler.metinSolgun, fontSize: 10.5)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.ad,
                              style: const TextStyle(
                                  color: Renkler.metin,
                                  fontSize: 14,
                                  height: 1.3)),
                          if (e.yer.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(e.yer,
                                  style: const TextStyle(
                                      color: Renkler.metinSolgun,
                                      fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
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
              style: const TextStyle(
                  color: Renkler.metinIkincil, fontSize: 13.5, height: 1.3)),
          trailing: const Icon(Icons.open_in_new,
              size: 15, color: Renkler.metinSolgun),
          onTap: () =>
              launchUrl(Uri.parse(b.url), mode: LaunchMode.externalApplication),
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
              style: const TextStyle(
                  color: Renkler.metinSolgun, fontSize: 13.5, height: 1.4)),
        ),
      );
}
