import 'package:flutter/material.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'duyuru_detay.dart';

/// Anasayfa: federasyon duyuru akışı. Takip edilen federasyonlar başa gelir.
class Anasayfa extends StatefulWidget {
  final Veri veri;
  const Anasayfa({super.key, required this.veri});

  @override
  State<Anasayfa> createState() => _AnasayfaDurumu();
}

class _AnasayfaDurumu extends State<Anasayfa> {
  String _kategori = 'tumu';

  static const _kategoriler = [
    ('tumu', 'Tümü'),
    ('kurs', 'Kurs'),
    ('musabaka', 'Müsabaka'),
    ('mevzuat', 'Mevzuat'),
    ('takvim', 'Takvim'),
    ('duyuru', 'Duyuru'),
  ];

  @override
  Widget build(BuildContext context) {
    final veri = widget.veri;
    final liste = veri.akis(kategori: _kategori);

    return Column(
      children: [
        _KategoriSeridi(
          secili: _kategori,
          kategoriler: _kategoriler,
          sec: (k) => setState(() => _kategori = k),
        ),
        if (veri.takipEdilen.isEmpty) const _TakipIpucu(),
        Expanded(
          child: liste.isEmpty
              ? const _BosDurum(mesaj: 'Bu kategoride duyuru yok')
              : RefreshIndicator(
                  onRefresh: veri.baslat,
                  color: Renkler.amblemAcik,
                  backgroundColor: Renkler.yuzey,
                  child: ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (_, i) => DuyuruKarti(
                      duyuru: liste[i],
                      takipte: veri.takipEdilen.contains(liste[i].federasyon),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DuyuruDetay(duyuru: liste[i]),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _KategoriSeridi extends StatelessWidget {
  final String secili;
  final List<(String, String)> kategoriler;
  final ValueChanged<String> sec;

  const _KategoriSeridi({
    required this.secili,
    required this.kategoriler,
    required this.sec,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Renkler.cizgi)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          itemCount: kategoriler.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (deger, ad) = kategoriler[i];
            final aktif = deger == secili;
            final renk = deger == 'tumu'
                ? Renkler.metin
                : Renkler.kategoriRengi(deger);
            return GestureDetector(
              onTap: () => sec(deger),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? renk.withValues(alpha: 0.15) : Renkler.yuzey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: aktif ? renk.withValues(alpha: 0.5) : Renkler.cizgi,
                  ),
                ),
                child: Text(
                  ad,
                  style: TextStyle(
                    color: aktif ? renk : Renkler.metinIkincil,
                    fontSize: 13.5,
                    fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _TakipIpucu extends StatelessWidget {
  const _TakipIpucu();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: Renkler.yuzey,
        child: const Text(
          'Branşını seç, sadece ilgilendiğin federasyonların duyuruları başa gelsin.',
          style: TextStyle(color: Renkler.metinIkincil, fontSize: 12.5),
        ),
      );
}

class _BosDurum extends StatelessWidget {
  final String mesaj;
  const _BosDurum({required this.mesaj});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          mesaj,
          style: const TextStyle(color: Renkler.metinSolgun, fontSize: 14),
        ),
      );
}
