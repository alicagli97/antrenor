import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Ayarlar: tema, bildirim, federasyon seçimi ve mağazaların zorunlu tuttuğu
/// sayfalar. Hesap yok — giriş/çıkış veya hesap silme ekranı da yok.
class AyarlarEkrani extends StatelessWidget {
  final Veri veri;
  final VoidCallback federasyonlaraGit;
  const AyarlarEkrani(
      {super.key, required this.veri, required this.federasyonlaraGit});

  static const site = 'https://alicagli97.github.io/antrenor';

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _Baslik('Tercihler'),
        SwitchListTile(
          value: veri.koyuTema,
          onChanged: veri.temayiDegistir,
          activeThumbColor: Renkler.kurs,
          secondary: Icon(
              veri.koyuTema ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: Renkler.metinIkincil),
          title: const Text('Koyu tema',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: Text(veri.koyuTema ? 'Açık' : 'Kapalı',
              style:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
        ),
        ListTile(
          leading: const Icon(Icons.star_border, color: Renkler.metinIkincil),
          title: const Text('Takip ettiğim federasyonlar',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: Text(
              veri.takipEdilen.isEmpty
                  ? 'Henüz federasyon seçilmedi'
                  : '${veri.takipEdilen.length} federasyon',
              style:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, color: Renkler.metinSolgun),
          onTap: federasyonlaraGit,
        ),
        ListTile(
          leading:
              const Icon(Icons.notifications_none, color: Renkler.metinIkincil),
          title: const Text('Bildirimler',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: const Text(
              'Takip edilen federasyonlarda yeni duyuru olduğunda haber ver',
              style: TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
          trailing: const Text('Yakında',
              style: TextStyle(color: Renkler.metinSolgun, fontSize: 12)),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bildirimler bir sonraki adımda açılacak')),
          ),
        ),
        const Divider(height: 28),
        const _Baslik('Uygulama'),
        _Satir(
          simge: Icons.info_outline,
          baslik: 'Hakkında',
          onTap: () => _hakkinda(context),
        ),
        _Satir(
          simge: Icons.privacy_tip_outlined,
          baslik: 'Gizlilik Politikası',
          onTap: () => _ac('$site/gizlilik.html'),
        ),
        _Satir(
          simge: Icons.delete_outline,
          baslik: 'Verilerin silinmesi',
          onTap: () => _ac('$site/veri-silme.html'),
        ),
        _Satir(
          simge: Icons.support_agent_outlined,
          baslik: 'Destek',
          onTap: () => _ac('$site/destek.html'),
        ),
        _Satir(
          simge: Icons.description_outlined,
          baslik: 'Lisanslar',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Antrenör',
            applicationVersion: '1.0.0',
          ),
        ),
        _Satir(
          simge: Icons.cleaning_services_outlined,
          baslik: 'Verileri sıfırla',
          onTap: () => _sifirla(context),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Antrenör bağımsız bir duyuru uygulamasıdır; federasyonlarla resmî '
            'bir bağlantısı yoktur. Duyurular kamuya açık resmî sayfalardan '
            'derlenir, içeriğin resmî hâli kaynaktadır.',
            style:
                TextStyle(color: Renkler.metinSolgun, fontSize: 12, height: 1.5),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
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
          backgroundColor: Renkler.yuzey,
          title: const Text('Verileri sıfırla',
              style: TextStyle(color: Renkler.metin, fontSize: 17)),
          content: const Text(
              'Takip listesi ve tercihler silinecek. Bu veriler yalnızca bu '
              'cihazda tutuluyor.',
              style: TextStyle(color: Renkler.metinIkincil, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Vazgeç',
                  style: TextStyle(color: Renkler.metinIkincil)),
            ),
            TextButton(
              onPressed: () async {
                for (final slug in veri.takipEdilen.toList()) {
                  await veri.takibiDegistir(slug);
                }
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Sıfırla',
                  style: TextStyle(color: Renkler.kurs)),
            ),
          ],
        ),
      );
}

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: Text(metin.toUpperCase(),
            style: const TextStyle(
                color: Renkler.metinSolgun,
                fontSize: 11.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600)),
      );
}

class _Satir extends StatelessWidget {
  final IconData simge;
  final String baslik;
  final VoidCallback onTap;
  const _Satir(
      {required this.simge, required this.baslik, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(simge, color: Renkler.metinIkincil),
        title: Text(baslik,
            style: const TextStyle(color: Renkler.metin, fontSize: 14.5)),
        trailing: const Icon(Icons.chevron_right, color: Renkler.metinSolgun),
        onTap: onTap,
      );
}
