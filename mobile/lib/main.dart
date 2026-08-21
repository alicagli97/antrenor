import 'package:flutter/material.dart';

import 'cekirdek/bildirim.dart';
import 'cekirdek/tema.dart';
import 'cekirdek/veri.dart';
import 'ekranlar/anasayfa.dart';
import 'ekranlar/ayarlar.dart';
import 'ekranlar/bildirimler.dart';
import 'ekranlar/federasyonlar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Bildirim.baslat();
  runApp(const AntrenorUygulamasi());
}

class AntrenorUygulamasi extends StatefulWidget {
  const AntrenorUygulamasi({super.key});

  @override
  State<AntrenorUygulamasi> createState() => _AntrenorUygulamasiDurumu();
}

class _AntrenorUygulamasiDurumu extends State<AntrenorUygulamasi> {
  final _veri = Veri();

  @override
  void initState() {
    super.initState();
    // Tema tercihi degisince tum uygulama yeniden cizilir
    _veri.addListener(_temayiUygula);
    _veri.baslat().then((_) => Bildirim.esitle(_veri.takipEdilen));
  }

  void _temayiUygula() {
    Renkler.paletiDegistir(_veri.koyuTema);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _veri.removeListener(_temayiUygula);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Renkler.paletiDegistir(_veri.koyuTema);
    return MaterialApp(
      title: 'Antrenör',
      debugShowCheckedModeBanner: false,
      theme: antrenorTemasi(),
      home: AnaKabuk(veri: _veri),
    );
  }
}

/// Dört sekme: Anasayfa · Federasyonlar · Bildirimler · Ayarlar
/// Üstte ayrı bir başlık çubuğu yok; her ekran kendi başlığını taşır ve
/// kaydırınca kaybolur, böylece tek menü hissi korunur.
class AnaKabuk extends StatefulWidget {
  final Veri veri;
  const AnaKabuk({super.key, required this.veri});

  @override
  State<AnaKabuk> createState() => _AnaKabukDurumu();
}

class _AnaKabukDurumu extends State<AnaKabuk> {
  late final Veri _veri = widget.veri;
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    _veri.addListener(_yenile);
    // Bildirime dokunulunca bildirimler sekmesine gidiyoruz; duyuru
    // kimligiyle derin baglanti sonraki adimda
    Bildirim.dinle((veri) => _sekmeyeGit('bildirimler'));
  }

  void _yenile() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _veri.removeListener(_yenile);
    super.dispose();
  }

  void _sekmeyeGit(String hedef) {
    final indeks = switch (hedef) {
      'federasyonlar' => 1,
      'bildirimler' => 2,
      'ayarlar' => 3,
      _ => 0,
    };
    setState(() => _sekme = indeks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Anasayfa kendi başlığını sliver olarak taşır; diğer sekmelerde
      // sade bir başlık yeterli
      appBar: _sekme == 0
          ? null
          : AppBar(title: Text(_baslik(_sekme))),
      body: SafeArea(child: _govde()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Anasayfa'),
          NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Federasyonlar'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Bildirimler'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ayarlar'),
        ],
      ),
    );
  }

  static String _baslik(int sekme) => switch (sekme) {
        1 => 'Federasyonlar',
        2 => 'Bildirimler',
        _ => 'Ayarlar',
      };

  Widget _govde() {
    if (_veri.yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_veri.hata != null && _veri.duyurular.isEmpty) {
      return _HataDurumu(mesaj: _veri.hata!, tekrar: _veri.baslat);
    }
    return switch (_sekme) {
      0 => Anasayfa(veri: _veri, sekmeyeGit: _sekmeyeGit),
      1 => FederasyonlarEkrani(veri: _veri),
      2 => BildirimlerEkrani(
          veri: _veri, federasyonlaraGit: () => _sekmeyeGit('federasyonlar')),
      _ => AyarlarEkrani(
          veri: _veri, federasyonlaraGit: () => _sekmeyeGit('federasyonlar')),
    };
  }
}

class _HataDurumu extends StatelessWidget {
  final String mesaj;
  final VoidCallback tekrar;
  const _HataDurumu({required this.mesaj, required this.tekrar});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 42, color: Renkler.metinSolgun),
              const SizedBox(height: 14),
              Text(mesaj,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Renkler.metinIkincil, fontSize: 14, height: 1.4)),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: tekrar,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Renkler.metin,
                    side: BorderSide(color: Renkler.cizgi)),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
}
