import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'duyuru_detay.dart';

/// Anasayfa: duyuru akışı. Üstte sunucudan yönetilen afiş alanı var;
/// içeriği banner.json ile değişir, uygulama güncellemesi gerekmez.
class Anasayfa extends StatefulWidget {
  final Veri veri;
  final ValueChanged<String> sekmeyeGit;
  const Anasayfa({super.key, required this.veri, required this.sekmeyeGit});

  @override
  State<Anasayfa> createState() => _AnasayfaDurumu();
}

class _AnasayfaDurumu extends State<Anasayfa> {
  String _kategori = 'tumu';

  static const _kategoriler = [
    ('tumu', 'Tümü'),
    ('musabaka', 'Müsabaka'),
    ('mevzuat', 'Mevzuat'),
    ('takvim', 'Takvim'),
    ('duyuru', 'Duyuru'),
  ];

  @override
  Widget build(BuildContext context) {
    final veri = widget.veri;
    final liste = veri.akis(kategori: _kategori);

    return RefreshIndicator(
      onRefresh: veri.baslat,
      color: Renkler.amblemAcik,
      backgroundColor: Renkler.yuzey,
      child: CustomScrollView(
        slivers: [
          // Başlık kaydırınca yukarı kaçar: alttaki menüyle çakışan
          // ikinci bir menü hissi vermesin
          SliverAppBar(
            floating: true,
            snap: true,
            titleSpacing: 16,
            title: const Text('ANTRENÖR',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0)),
            actions: [
              if (veri.sonGuncelleme != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(_guncelleme(veri.sonGuncelleme!),
                        style: const TextStyle(
                            color: Renkler.metinSolgun, fontSize: 11.5)),
                  ),
                ),
            ],
          ),
          if (veri.afis.aktif)
            SliverToBoxAdapter(
              child: _AfisKarti(
                  afis: veri.afis, sekmeyeGit: widget.sekmeyeGit),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _KategoriBasligi(
              secili: _kategori,
              kategoriler: _kategoriler,
              sec: (k) => setState(() => _kategori = k),
            ),
          ),
          if (liste.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Bu kategoride duyuru yok',
                    style:
                        TextStyle(color: Renkler.metinSolgun, fontSize: 14)),
              ),
            )
          else
            SliverList.builder(
              itemCount: liste.length,
              itemBuilder: (_, i) => DuyuruKarti(
                duyuru: liste[i],
                takipte: veri.takipEdilen.contains(liste[i].federasyon),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DuyuruDetay(duyuru: liste[i]))),
              ),
            ),
        ],
      ),
    );
  }

  static String _guncelleme(DateTime t) {
    final fark = DateTime.now().difference(t);
    if (fark.inMinutes < 1) return 'şimdi güncellendi';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    return '${fark.inHours} sa önce';
  }
}

/// Sunucudan yönetilen afiş: bilgi kartı, sponsor alanı veya uyarı.
class _AfisKarti extends StatelessWidget {
  final Afis afis;
  final ValueChanged<String> sekmeyeGit;
  const _AfisKarti({required this.afis, required this.sekmeyeGit});

  @override
  Widget build(BuildContext context) {
    final renk = _renk(afis.renk);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_simge(afis.tur), size: 16, color: renk),
              const SizedBox(width: 7),
              Expanded(
                child: Text(afis.baslik,
                    style: TextStyle(
                        color: renk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              if (afis.tur == 'sponsor')
                const Text('Sponsorlu',
                    style:
                        TextStyle(color: Renkler.metinSolgun, fontSize: 10.5)),
            ],
          ),
          if (afis.metin.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(afis.metin,
                style: const TextStyle(
                    color: Renkler.metinIkincil, fontSize: 13, height: 1.4)),
          ],
          if (afis.butonMetni.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _tikla(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(afis.butonMetni,
                      style: TextStyle(
                          color: renk,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: renk),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _tikla(BuildContext context) {
    if (afis.url.isNotEmpty) {
      launchUrl(Uri.parse(afis.url), mode: LaunchMode.externalApplication);
      return;
    }
    if (afis.butonHedefi.isNotEmpty) sekmeyeGit(afis.butonHedefi);
  }

  static IconData _simge(String tur) => switch (tur) {
        'sponsor' => Icons.campaign_outlined,
        'uyari' => Icons.warning_amber_outlined,
        _ => Icons.info_outline,
      };

  static Color _renk(String kod) {
    final temiz = kod.replaceAll('#', '');
    return Color(int.tryParse('FF$temiz', radix: 16) ?? 0xFFE0A33C);
  }
}

class _KategoriBasligi extends SliverPersistentHeaderDelegate {
  final String secili;
  final List<(String, String)> kategoriler;
  final ValueChanged<String> sec;

  _KategoriBasligi(
      {required this.secili, required this.kategoriler, required this.sec});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(
        height: 52,
        color: Renkler.zemin,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          itemCount: kategoriler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (deger, ad) = kategoriler[i];
            final aktif = deger == secili;
            final renk =
                deger == 'tumu' ? Renkler.metin : Renkler.kategoriRengi(deger);
            return GestureDetector(
              onTap: () => sec(deger),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif ? renk.withValues(alpha: 0.15) : Renkler.yuzey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          aktif ? renk.withValues(alpha: 0.5) : Renkler.cizgi),
                ),
                child: Text(ad,
                    style: TextStyle(
                        color: aktif ? renk : Renkler.metinIkincil,
                        fontSize: 13.5,
                        fontWeight:
                            aktif ? FontWeight.w600 : FontWeight.w400)),
              ),
            );
          },
        ),
      );

  @override
  bool shouldRebuild(covariant _KategoriBasligi eski) => eski.secili != secili;
}
