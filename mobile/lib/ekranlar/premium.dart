import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/abonelik.dart';
import '../cekirdek/reklam.dart';
import '../cekirdek/tema.dart';

/// Premium tanıtım ve satın alma ekranı.
///
/// Mağazaların istediği bilgiler burada eksiksiz duruyor: ne alındığı, fiyatı,
/// süresi, kendiliğinden yenilendiği, nasıl iptal edileceği ve koşul
/// bağlantıları. Apple ayrıca "Satın alımları geri yükle" düğmesini şart
/// koşuyor.
class PremiumEkrani extends StatefulWidget {
  const PremiumEkrani({super.key});

  static const site = 'https://alicagli97.github.io/antrenor';

  /// Ödeme duvarını alttan açar. Kullanıcı premium olduysa true döner.
  static Future<bool> ac(BuildContext context) async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumEkrani(), fullscreenDialog: true),
    );
    return sonuc ?? Abonelik.ornek.premium;
  }

  @override
  State<PremiumEkrani> createState() => _PremiumDurumu();
}

class _PremiumDurumu extends State<PremiumEkrani> {
  final _abonelik = Abonelik.ornek;
  String _secili = Abonelik.yillik;

  @override
  void initState() {
    super.initState();
    _abonelik.addListener(_yenile);
  }

  void _yenile() {
    if (!mounted) return;
    setState(() {});
    if (_abonelik.premium) {
      Reklam.temizle();
      Navigator.of(context).maybePop(true);
    }
  }

  @override
  void dispose() {
    _abonelik.removeListener(_yenile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urunler = _abonelik.urunler;
    final aylik = _abonelik.aylikUrun;
    final yillik = _abonelik.yillikUrun;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrenör Premium', style: TextStyle(fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Olcu.kenar, 6, Olcu.kenar, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Olcu.kartYaricap),
              border: Border.all(color: Renkler.kurs.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Renkler.kurs.withValues(alpha: 0.18),
                  Renkler.kurs.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: Renkler.kurs, size: 30),
                const SizedBox(height: 14),
                Text('Reklamsız ve sınırsız', style: Yazi.baslik),
                const SizedBox(height: 8),
                Text(
                  'Takip ettiğin her federasyonun kurs, seminer ve talimat '
                  'duyurusu, araya reklam girmeden.',
                  style: Yazi.govde.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _Fayda(
            simge: Icons.block_rounded,
            baslik: 'Hiç reklam yok',
            metin: 'Duyuruları açmak için reklam izlemezsin.',
          ),
          const _Fayda(
            simge: Icons.star_rounded,
            baslik: 'Sınırsız federasyon takibi',
            metin: 'Ücretsiz sürümde 1 federasyon takip edilir; '
                'premiumda istediğin kadar.',
          ),
          const _Fayda(
            simge: Icons.notifications_active_rounded,
            baslik: 'Takip ettiğin her federasyondan bildirim',
            metin: 'Yeni duyuru yayımlandığı anda telefonuna düşer.',
          ),
          const SizedBox(height: 22),
          if (!_abonelik.magazaHazir || urunler.isEmpty)
            _MagazaYok(yenile: _abonelik.urunleriGetir)
          else ...[
            if (yillik != null)
              _PlanKarti(
                urun: yillik,
                baslik: 'Yıllık',
                rozet: 'EN AVANTAJLI',
                secili: _secili == Abonelik.yillik,
                onTap: () => setState(() => _secili = Abonelik.yillik),
              ),
            if (aylik != null)
              _PlanKarti(
                urun: aylik,
                baslik: 'Aylık',
                secili: _secili == Abonelik.aylik,
                onTap: () => setState(() => _secili = Abonelik.aylik),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Renkler.kurs,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _abonelik.islemde ? null : _satinAl,
              child: _abonelik.islemde
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Premium\'a geç',
                      style: Yazi.govde.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: Renkler.koyuMu
                              ? const Color(0xFF13181F)
                              : Colors.white)),
            ),
          ],
          if (_abonelik.sonHata != null) ...[
            const SizedBox(height: 10),
            Text(_abonelik.sonHata!,
                textAlign: TextAlign.center,
                style: Yazi.kucuk.copyWith(color: Renkler.musabaka)),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: _abonelik.islemde ? null : _abonelik.geriYukle,
            child: Text('Satın alımları geri yükle',
                style: Yazi.govde.copyWith(color: Renkler.metinIkincil)),
          ),
          const SizedBox(height: 8),
          Text(
            'Abonelik, iptal edilmediği sürece dönem sonunda kendiliğinden '
            'yenilenir ve ücret mağaza hesabınızdan tahsil edilir. Yenilemeyi '
            'dönem bitiminden en az 24 saat önce, telefonunuzun mağaza '
            'ayarlarındaki abonelikler bölümünden durdurabilirsiniz.',
            style: Yazi.kucuk.copyWith(height: 1.55),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Baglanti(
                  metin: 'Kullanım Koşulları',
                  url: '${PremiumEkrani.site}/kosullar.html'),
              Text('  ·  ', style: Yazi.kucuk),
              _Baglanti(
                  metin: 'Gizlilik Politikası',
                  url: '${PremiumEkrani.site}/gizlilik.html'),
            ],
          ),
        ],
      ),
    );
  }

  void _satinAl() {
    final urun = _secili == Abonelik.yillik
        ? _abonelik.yillikUrun
        : _abonelik.aylikUrun;
    if (urun != null) _abonelik.satinAl(urun);
  }
}

class _Fayda extends StatelessWidget {
  final IconData simge;
  final String baslik;
  final String metin;
  const _Fayda(
      {required this.simge, required this.baslik, required this.metin});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Renkler.kurs.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(simge, size: 18, color: Renkler.kurs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik,
                      style: Yazi.govde.copyWith(
                          color: Renkler.metin,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(metin, style: Yazi.kucuk.copyWith(height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PlanKarti extends StatelessWidget {
  final ProductDetails urun;
  final String baslik;
  final String? rozet;
  final bool secili;
  final VoidCallback onTap;

  const _PlanKarti({
    required this.urun,
    required this.baslik,
    required this.secili,
    required this.onTap,
    this.rozet,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              color: secili
                  ? Renkler.kurs.withValues(alpha: 0.10)
                  : Renkler.yuzey,
              borderRadius: BorderRadius.circular(Olcu.kartYaricap),
              border: Border.all(
                color: secili
                    ? Renkler.kurs.withValues(alpha: 0.6)
                    : Renkler.cizgi,
                width: secili ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                    secili
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: secili ? Renkler.kurs : Renkler.metinSolgun),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(baslik,
                              style: Yazi.govde.copyWith(
                                  color: Renkler.metin,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700)),
                          if (rozet != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Renkler.kurs.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(rozet!,
                                  style: Yazi.etiket.copyWith(
                                      color: Renkler.kurs, fontSize: 9)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(urun.title.isEmpty ? 'Antrenör Premium' : urun.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Yazi.kucuk),
                    ],
                  ),
                ),
                Text(urun.price,
                    style: Yazi.govde.copyWith(
                        color: Renkler.metin,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

class _MagazaYok extends StatelessWidget {
  final Future<void> Function() yenile;
  const _MagazaYok({required this.yenile});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: kartYuzeyi(),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined,
                color: Renkler.metinSolgun, size: 26),
            const SizedBox(height: 10),
            Text(
              'Abonelik planları şu anda mağazadan alınamadı. '
              'İnternet bağlantını kontrol edip yeniden dene.',
              textAlign: TextAlign.center,
              style: Yazi.govde.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: yenile,
              style: OutlinedButton.styleFrom(
                  foregroundColor: Renkler.metin,
                  side: BorderSide(color: Renkler.cizgi)),
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      );
}

class _Baglanti extends StatelessWidget {
  final String metin;
  final String url;
  const _Baglanti({required this.metin, required this.url});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(metin,
            style: Yazi.kucuk.copyWith(
                color: Renkler.metinIkincil,
                decoration: TextDecoration.underline)),
      );
}
