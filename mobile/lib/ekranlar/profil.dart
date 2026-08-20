import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import 'federasyon_secimi.dart';

/// Profil: takip ayarları ve mağazaların zorunlu tuttuğu sayfalar.
/// Hesap yok — bu yüzden giriş/çıkış veya hesap silme ekranı da yok.
class ProfilEkrani extends StatelessWidget {
  final Veri veri;
  const ProfilEkrani({super.key, required this.veri});

  static const site = 'https://alicagli97.github.io/antrenor';

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _Baslik('Takip'),
        ListTile(
          leading: const Icon(Icons.sports_outlined, color: Renkler.metinIkincil),
          title: const Text('Federasyonlarım',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: Text(
              veri.takipEdilen.isEmpty
                  ? 'Henüz federasyon seçilmedi'
                  : '${veri.takipEdilen.length} federasyon takip ediliyor',
              style:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, color: Renkler.metinSolgun),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FederasyonSecimi(veri: veri))),
        ),
        ListTile(
          leading:
              const Icon(Icons.notifications_none, color: Renkler.metinIkincil),
          title: const Text('Bildirimler',
              style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          subtitle: const Text('Yakında',
              style: TextStyle(color: Renkler.metinSolgun, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, color: Renkler.metinSolgun),
          onTap: () {},
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
