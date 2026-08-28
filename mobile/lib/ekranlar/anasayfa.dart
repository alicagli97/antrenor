import 'package:flutter/material.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import '../parcalar/erisim.dart';

/// Anasayfa: günün özeti, sunucudan yönetilen afiş ve duyuru akışı.
class Anasayfa extends StatefulWidget {
  final Veri veri;
  final ValueChanged<String> sekmeyeGit;
  final VoidCallback aramayaGit;
  const Anasayfa({
    super.key,
    required this.veri,
    required this.sekmeyeGit,
    required this.aramayaGit,
  });

  @override
  State<Anasayfa> createState() => _AnasayfaDurumu();
}

class _AnasayfaDurumu extends State<Anasayfa> {
  String _kategori = 'tumu';

  // Kurs, vize ve seminer duyurulari antrenor icin uygulamanin asil sebebi;
  // bu yuzden "Tümü"den hemen sonra geliyor.
  static const _kategoriler = [
    ('tumu', 'Tümü'),
    ('kurs', 'Kurs & seminer'),
    ('musabaka', 'Müsabaka'),
    ('mevzuat', 'Mevzuat'),
    ('takvim', 'Takvim'),
    ('duyuru', 'Duyuru'),
  ];

  List<Duyuru>? _kategoriListesi;   // null: "Tümü" seçili
  bool _kategoriYukleniyor = false;

  Future<void> _kategoriSec(String kategori) async {
    if (kategori == _kategori) return;
    setState(() {
      _kategori = kategori;
      _kategoriListesi = null;
      _kategoriYukleniyor = kategori != 'tumu';
    });
    if (kategori == 'tumu') return;

    final liste = await widget.veri.kategoriAkisi(kategori);
    if (!mounted || _kategori != kategori) return;
    setState(() {
      _kategoriListesi = liste;
      _kategoriYukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final veri = widget.veri;
    final liste = _kategori == 'tumu' ? veri.akis() : (_kategoriListesi ?? const <Duyuru>[]);

    return RefreshIndicator(
      onRefresh: veri.baslat,
      color: Renkler.amblemAcik,
      backgroundColor: Renkler.yuzey,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
              child: _Tepe(veri: veri, aramayaGit: widget.aramayaGit)),
          if (veri.cevrimdisi)
            SliverToBoxAdapter(child: _CevrimdisiSeridi(veri: veri)),
          if (veri.afis.aktif)
            SliverToBoxAdapter(
              child: _AfisKarti(
                  afis: veri.afis, sekmeyeGit: widget.sekmeyeGit),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SuzgecSeridi(
              secili: _kategori,
              kategoriler: _kategoriler,
              sec: _kategoriSec,
            ),
          ),
          if (_kategoriYukleniyor)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (liste.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: Text('Bu kategoride duyuru yok', style: Yazi.govde)),
            )
          else
            SliverList.builder(
              itemCount: liste.length,
              itemBuilder: (_, i) => DuyuruKarti(
                duyuru: liste[i],
                takipte: veri.takipEdilen.contains(liste[i].federasyon),
                onTap: () => duyuruyuAc(context, liste[i]),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }
}

/// Üst blok: marka, güncellik ve günün sayıları
class _Tepe extends StatelessWidget {
  final Veri veri;
  final VoidCallback aramayaGit;
  const _Tepe({required this.veri, required this.aramayaGit});

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    final sonGun = veri.duyurular
        .where((d) =>
            d.yayinTarihi != null &&
            bugun.difference(d.yayinTarihi!).inHours < 24)
        .toList();
    final kurs = veri.duyurular.where((d) => d.antrenorIcin).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 8, Olcu.kenar, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ANTRENÖR',
                        style: Yazi.dev.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      veri.takipEdilen.isEmpty
                          ? '${veri.federasyonlar.length} federasyon izleniyor'
                          : '${veri.takipEdilen.length} federasyon takipte',
                      style: Yazi.kucuk,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ara',
                icon: Icon(Icons.search, color: Renkler.metinIkincil),
                onPressed: aramayaGit,
              ),
              if (veri.sonGuncelleme != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Renkler.takvim.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Renkler.takvim.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: Renkler.takvim, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('GÜNCEL',
                          style: Yazi.etiket
                              .copyWith(color: Renkler.takvim, fontSize: 9.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SayiKutusu(
                  sayi: sonGun.length,
                  etiket: 'SON 24 SAAT',
                  renk: Renkler.musabaka),
              const SizedBox(width: 10),
              _SayiKutusu(
                  sayi: kurs, etiket: 'ANTRENÖR', renk: Renkler.kurs),
              const SizedBox(width: 10),
              _SayiKutusu(
                  sayi: veri.duyurular.length,
                  etiket: 'AKIŞTA',
                  renk: Renkler.duyuru),
            ],
          ),
        ],
      ),
    );
  }
}

class _SayiKutusu extends StatelessWidget {
  final int sayi;
  final String etiket;
  final Color renk;
  const _SayiKutusu(
      {required this.sayi, required this.etiket, required this.renk});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: kartYuzeyi(vurgu: renk),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$sayi', style: Yazi.rakam.copyWith(color: renk)),
              const SizedBox(height: 5),
              Text(etiket,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Yazi.etiket.copyWith(fontSize: 9.5)),
            ],
          ),
        ),
      );
}

/// Sunucudan yönetilen afiş: bilgi kartı, sponsor alanı veya uyarı.
class _AfisKarti extends StatelessWidget {
  final Afis afis;
  final ValueChanged<String> sekmeyeGit;
  const _AfisKarti({required this.afis, required this.sekmeyeGit});

  @override
  Widget build(BuildContext context) {
    final renk = _renk(afis.renk);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 0, Olcu.kenar, 16),
      child: GestureDetector(
        onTap: () => _tikla(context),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                renk.withValues(alpha: 0.16),
                renk.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(Olcu.kartYaricap),
            border: Border.all(color: renk.withValues(alpha: 0.30)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_simge(afis.tur), size: 15, color: renk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(afis.baslik,
                        style: Yazi.kartBaslik
                            .copyWith(color: renk, fontSize: 15)),
                  ),
                  if (afis.tur == 'sponsor')
                    Text('SPONSORLU',
                        style: Yazi.etiket.copyWith(fontSize: 9)),
                ],
              ),
              if (afis.metin.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(afis.metin, style: Yazi.govde.copyWith(fontSize: 13.5)),
              ],
              if (afis.butonMetni.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(afis.butonMetni,
                        style: Yazi.govde.copyWith(
                            color: renk,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                    const SizedBox(width: 5),
                    Icon(Icons.arrow_forward_rounded, size: 15, color: renk),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _tikla(BuildContext context) {
    if (afis.url.isNotEmpty) {
      Baglanti.ac(context, afis.url);
      return;
    }
    if (afis.butonHedefi.isNotEmpty) sekmeyeGit(afis.butonHedefi);
  }

  static IconData _simge(String tur) => switch (tur) {
        'sponsor' => Icons.campaign_rounded,
        'uyari' => Icons.warning_amber_rounded,
        _ => Icons.bolt_rounded,
      };

  static Color _renk(String kod) {
    final temiz = kod.replaceAll('#', '');
    return Color(int.tryParse('FF$temiz', radix: 16) ?? 0xFFF2A93B);
  }
}

/// Yapışkan süzgeç şeridi — seçili olan dolu, diğerleri hatlı
class _SuzgecSeridi extends SliverPersistentHeaderDelegate {
  final String secili;
  final List<(String, String)> kategoriler;
  final ValueChanged<String> sec;

  _SuzgecSeridi(
      {required this.secili, required this.kategoriler, required this.sec});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(
        height: 56,
        color: Renkler.zemin,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(Olcu.kenar, 8, Olcu.kenar, 12),
          itemCount: kategoriler.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (deger, ad) = kategoriler[i];
            final aktif = deger == secili;
            final renk =
                deger == 'tumu' ? Renkler.metin : Renkler.kategoriRengi(deger);
            return GestureDetector(
              onTap: () => sec(deger),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: aktif
                      ? renk.withValues(alpha: 0.16)
                      : Renkler.yuzey.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: aktif
                          ? renk.withValues(alpha: 0.45)
                          : Renkler.cizgi),
                ),
                child: Row(
                  children: [
                    if (deger != 'tumu') ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: renk, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(ad,
                        style: Yazi.govde.copyWith(
                          fontSize: 13.5,
                          color: aktif ? renk : Renkler.metinIkincil,
                          fontWeight:
                              aktif ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            );
          },
        ),
      );

  @override
  bool shouldRebuild(covariant _SuzgecSeridi eski) => eski.secili != secili;
}

/// Veri diskteki kopyadan geliyorsa dürüstçe söyler: kullanıcı bayat
/// bilgiyle kurs başvurusu kaçırmasın.
class _CevrimdisiSeridi extends StatelessWidget {
  final Veri veri;
  const _CevrimdisiSeridi({required this.veri});

  @override
  Widget build(BuildContext context) {
    final t = veri.onbellekTarihi;
    final ne = t == null
        ? 'kayıtlı kopya'
        : '${t.day.toString().padLeft(2, '0')}.'
            '${t.month.toString().padLeft(2, '0')} '
            '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')} kopyası';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 0, Olcu.kenar, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Renkler.mevzuat.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Renkler.mevzuat.withValues(alpha: 0.28)),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off, size: 17, color: Renkler.mevzuat),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Çevrimdışısınız — $ne gösteriliyor',
              style: TextStyle(
                  color: Renkler.metinIkincil, fontSize: 12.5, height: 1.35),
            ),
          ),
        ]),
      ),
    );
  }
}
