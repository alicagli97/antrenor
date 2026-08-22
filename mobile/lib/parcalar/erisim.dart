import 'package:flutter/material.dart';

import '../cekirdek/abonelik.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/reklam.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../ekranlar/duyuru_detay.dart';
import '../ekranlar/premium.dart';

/// Ücretsiz sürümün sınırları tek yerde toplanıyor: duyuru açarken reklam,
/// takipte tek federasyon. Premium'da ikisi de kalkar.

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

/// Takip sınırı denetimi. Sınıra takılırsa ödeme duvarını açar ve kullanıcı
/// premium olursa true döner.
Future<bool> takipEklenebilirMi(BuildContext context, Veri veri) async {
  if (veri.takipEklenebilir) return true;

  final gecti = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Renkler.yuzey,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (c) => _TakipSiniri(mevcut: veri.takipEdilen.length),
      ) ??
      false;

  if (!gecti || !context.mounted) return false;
  return PremiumEkrani.ac(context);
}

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

class _TakipSiniri extends StatelessWidget {
  final int mevcut;
  const _TakipSiniri({required this.mevcut});

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
                color: Renkler.kurs.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.star_rounded, color: Renkler.kurs, size: 22),
            ),
            const SizedBox(height: 16),
            Text('Takip sınırına ulaştın', style: Yazi.baslik),
            const SizedBox(height: 10),
            Text(
              'Ücretsiz sürümde ${Veri.ucretsizTakipSiniri} federasyon takip '
              'edilebiliyor. Birden çok branşta çalışıyorsan Premium ile '
              'istediğin kadar federasyonu takip edebilir, hepsinin '
              'bildirimini alabilirsin.',
              style: Yazi.govde.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Renkler.kurs,
                foregroundColor:
                    Renkler.koyuMu ? const Color(0xFF13181F) : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.workspace_premium_rounded, size: 19),
              label: Text('Premium\'u incele',
                  style: Yazi.govde.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Renkler.koyuMu
                          ? const Color(0xFF13181F)
                          : Colors.white)),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Şimdi değil',
                    style: Yazi.govde.copyWith(color: Renkler.metinIkincil)),
              ),
            ),
          ],
        ),
      );
}
