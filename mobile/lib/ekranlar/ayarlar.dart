import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/bildirim.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Ayarlar: tercihler ve mağazaların zorunlu tuttuğu sayfalar.
/// Hesap yok — giriş/çıkış veya hesap silme ekranı da yok.
class AyarlarEkrani extends StatelessWidget {
  final Veri veri;
  final VoidCallback federasyonlaraGit;
  const AyarlarEkrani(
      {super.key, required this.veri, required this.federasyonlaraGit});

  static const site = 'https://alicagli97.github.io/antrenor';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 4, Olcu.kenar, 28),
      children: [
        const _BolumBasligi('Tercihler'),
        _Kart(children: [
          _Satir(
            simge: veri.koyuTema
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            renk: Renkler.mevzuat,
            baslik: 'Koyu tema',
            alt: veri.koyuTema ? 'Açık' : 'Kapalı',
            son: Switch(
              value: veri.koyuTema,
              onChanged: veri.temayiDegistir,
              activeThumbColor: Renkler.kurs,
            ),
          ),
          const _Ayrac(),
          _Satir(
            simge: Icons.star_rounded,
            renk: Renkler.kurs,
            baslik: 'Takip ettiğim federasyonlar',
            alt: veri.takipEdilen.isEmpty
                ? 'Henüz federasyon seçilmedi'
                : '${veri.takipEdilen.length} federasyon',
            onTap: federasyonlaraGit,
          ),
          const _Ayrac(),
          _Satir(
            simge: Icons.notifications_active_rounded,
            renk: Renkler.musabaka,
            baslik: 'Bildirimler',
            alt: veri.takipEdilen.isEmpty
                ? 'Önce federasyon takip et'
                : 'Takip ettiğin federasyonlarda yeni duyuru olunca haber ver',
            onTap: () => _bildirimIzni(context),
          ),
        ]),
        const _BolumBasligi('Uygulama'),
        _Kart(children: [
          _Satir(
              simge: Icons.info_rounded,
              renk: Renkler.duyuru,
              baslik: 'Hakkında',
              onTap: () => _hakkinda(context)),
          const _Ayrac(),
          _Satir(
              simge: Icons.shield_rounded,
              renk: Renkler.takvim,
              baslik: 'Gizlilik Politikası',
              onTap: () => _ac('$site/gizlilik.html')),
          const _Ayrac(),
          _Satir(
              simge: Icons.delete_sweep_rounded,
              renk: Renkler.duyuru,
              baslik: 'Verilerin silinmesi',
              onTap: () => _ac('$site/veri-silme.html')),
          const _Ayrac(),
          _Satir(
              simge: Icons.support_agent_rounded,
              renk: Renkler.duyuru,
              baslik: 'Destek',
              onTap: () => _ac('$site/destek.html')),
          const _Ayrac(),
          _Satir(
              simge: Icons.article_rounded,
              renk: Renkler.duyuru,
              baslik: 'Lisanslar',
              onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Antrenör',
                    applicationVersion: '1.0.0',
                  )),
          const _Ayrac(),
          _Satir(
              simge: Icons.restart_alt_rounded,
              renk: Renkler.duyuru,
              baslik: 'Verileri sıfırla',
              onTap: () => _sifirla(context)),
        ]),
        const SizedBox(height: 18),
        Text(
          'Antrenör bağımsız bir duyuru uygulamasıdır; federasyonlarla resmî '
          'bir bağlantısı yoktur. Duyurular kamuya açık resmî sayfalardan '
          'derlenir, içeriğin resmî hâli kaynaktadır.',
          style: Yazi.kucuk.copyWith(height: 1.55),
        ),
      ],
    );
  }

  /// Sistem izin penceresinden önce nedenini açıklıyoruz: izin bir kez
  /// soruluyor, reddedilirse geri dönüşü zor.
  Future<void> _bildirimIzni(BuildContext context) async {
    if (!Bildirim.hazir) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bildirim altyapısı bu sürümde kapalı')));
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Renkler.yuzeyYuksek,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Olcu.kartYaricap)),
        title: Text('Bildirimlere izin ver', style: Yazi.baslik),
        content: Text(
            'Takip ettiğin federasyonlarda yeni kurs, vize veya talimat '
            'yayımlandığında haber veririz. Sadece seçtiğin federasyonlar '
            'için bildirim gönderilir.',
            style: Yazi.govde),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Şimdi değil',
                style: Yazi.govde.copyWith(color: Renkler.metinIkincil)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Renkler.kurs.withValues(alpha: 0.18),
                foregroundColor: Renkler.kurs),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('İzin ver'),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;

    final verildi = await Bildirim.izinIste();
    if (verildi) await Bildirim.esitle(veri.takipEdilen);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(verildi
          ? 'Bildirimler açıldı'
          : 'İzin verilmedi; telefon ayarlarından açabilirsin'),
    ));
  }

  static void _ac(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  static void _hakkinda(BuildContext context) => showAboutDialog(
        context: context,
        applicationName: 'Antrenör',
        applicationVersion: '1.0.0',
        applicationLegalese:
            'Türkiye spor federasyonlarının duyuru, faaliyet takvimi ve '
            'mevzuatını tek yerde toplar.\n\nFederasyonlarla resmî bağlantısı '
            'olmayan bağımsız bir uygulamadır.',
      );

  void _sifirla(BuildContext context) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Renkler.yuzeyYuksek,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Olcu.kartYaricap)),
          title: Text('Verileri sıfırla', style: Yazi.baslik),
          content: Text(
              'Takip listesi ve tercihler silinecek. Bu veriler yalnızca bu '
              'cihazda tutuluyor.',
              style: Yazi.govde),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('Vazgeç',
                  style: Yazi.govde.copyWith(color: Renkler.metinIkincil)),
            ),
            TextButton(
              onPressed: () async {
                for (final slug in veri.takipEdilen.toList()) {
                  await veri.takibiDegistir(slug);
                }
                if (c.mounted) Navigator.pop(c);
              },
              child:
                  Text('Sıfırla', style: Yazi.govde.copyWith(color: Renkler.kurs)),
            ),
          ],
        ),
      );
}

class _BolumBasligi extends StatelessWidget {
  final String metin;
  const _BolumBasligi(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(metin.toUpperCase(), style: Yazi.etiket),
      );
}

class _Kart extends StatelessWidget {
  final List<Widget> children;
  const _Kart({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: kartYuzeyi(),
        child: Column(children: children),
      );
}

class _Ayrac extends StatelessWidget {
  const _Ayrac();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 58),
        child: Divider(height: 1),
      );
}

class _Satir extends StatelessWidget {
  final IconData simge;
  final Color renk;
  final String baslik;
  final String? alt;
  final Widget? son;
  final VoidCallback? onTap;

  const _Satir({
    required this.simge,
    required this.renk,
    required this.baslik,
    this.alt,
    this.son,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Olcu.kartYaricap),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(simge, size: 17, color: renk),
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
                    if (alt != null) ...[
                      const SizedBox(height: 2),
                      Text(alt!, style: Yazi.kucuk),
                    ],
                  ],
                ),
              ),
              son ??
                  Icon(Icons.chevron_right_rounded,
                      color: Renkler.metinSolgun, size: 20),
            ],
          ),
        ),
      );
}
