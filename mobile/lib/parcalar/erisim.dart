import 'package:flutter/material.dart';

import '../cekirdek/abonelik.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/reklam.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../ekranlar/duyuru_detay.dart';
import '../ekranlar/premium.dart';

/// Ücretsiz sürümün tek sınırı burada: duyuru açarken kısa bir reklam.
/// Federasyon takibi sınırsız; Premium'un karşılığı reklamsızlıktır.

/// Bu oturumda reklam izlenerek açılmış duyurular. Kullanıcı geri dönüp aynı
/// duyuruya tekrar girdiğinde ikinci kez reklam izlemez.
final Set<String> _acilanlar = {};

/// Bir duyuruyu açar. Ücretsiz kullanıcıya önce ödüllü reklam sunulur.
Future<void> duyuruyuAc(BuildContext context, Duyuru duyuru) async {
  final gezgin = Navigator.of(context);

  void detayaGit() => gezgin.push(
      MaterialPageRoute(builder: (_) => DuyuruDetay(duyuru: duyuru)));

  if (Abonelik.ornek.premium || _acilanlar.contains(duyuru.id)) {
    detayaGit();
    return;
  }

  final secim = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Renkler.yuzey,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => _ReklamKapisi(baslik: duyuru.baslik),
  );

  if (secim == 'premium') {
    if (!context.mounted) return;
    final premiumOldu = await PremiumEkrani.ac(context);
    if (premiumOldu) detayaGit();
    return;
  }
  if (secim != 'reklam') return;

  // Reklam hazır değilse kısa bir bekleme olabilir; kullanıcı boş ekrana
  // bakmasın diye gösterge açıyoruz.
  final beklemeVar = !Reklam.reklamHazir;
  if (beklemeVar && context.mounted) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.4)),
      ),
    );
  }

  final acilabilir = await Reklam.odulluGoster();

  if (beklemeVar) gezgin.canPop() ? gezgin.pop() : null;

  if (acilabilir) {
    _acilanlar.add(duyuru.id);
    detayaGit();
  }
}

/// Takip sınırı kaldırıldı: ücretsiz sürümde de istenen kadar federasyon
/// takip edilebiliyor. Premium'un karşılığı artık yalnızca reklamsızlık.
/// Çağrı noktaları korunuyor; sınır geri gelirse değişecek tek yer burası.
Future<bool> takipEklenebilirMi(BuildContext context, Veri veri) async => true;

class _Tutamak extends StatelessWidget {
  const _Tutamak();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(
            color: Renkler.cizgiParlak,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _ReklamKapisi extends StatelessWidget {
  final String baslik;
  const _ReklamKapisi({required this.baslik});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Tutamak(),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Renkler.duyuru.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.play_circle_outline_rounded,
                  color: Renkler.duyuru, size: 22),
            ),
            const SizedBox(height: 16),
            Text('Duyuruyu aç', style: Yazi.baslik),
            const SizedBox(height: 8),
            Text(baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Yazi.govde.copyWith(
                    color: Renkler.metinIkincil, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Ücretsiz sürümde duyuruları kısa bir reklam izleyerek '
              'açabilirsin. Premium\'da reklam hiç çıkmaz.',
              style: Yazi.govde.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Renkler.duyuru,
                foregroundColor:
                    Renkler.koyuMu ? const Color(0xFF13181F) : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, 'reklam'),
              icon: const Icon(Icons.slideshow_rounded, size: 19),
              label: Text('Reklam izle ve aç',
                  style: Yazi.govde.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Renkler.koyuMu
                          ? const Color(0xFF13181F)
                          : Colors.white)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Renkler.kurs,
                side: BorderSide(color: Renkler.kurs.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, 'premium'),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: const Text('Premium ile reklamsız oku'),
            ),
          ],
        ),
      );
}
