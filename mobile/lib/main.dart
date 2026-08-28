import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'cekirdek/abonelik.dart';
import 'cekirdek/bildirim.dart';
import 'cekirdek/hatirlatici.dart';
import 'cekirdek/profil.dart';
import 'cekirdek/reklam.dart';
import 'cekirdek/tema.dart';
import 'cekirdek/veri.dart';
import 'ekranlar/anasayfa.dart';
import 'ekranlar/arama.dart';
import 'ekranlar/ayarlar.dart';
import 'ekranlar/bilgi.dart';
import 'ekranlar/bildirimler.dart';
import 'ekranlar/federasyonlar.dart';
import 'ekranlar/kaydedilenler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase, magaza ve reklam kurulumu burada beklenmiyor: hepsi ilk kare
  // cizildikten sonra sirayla baslatiliyor (bkz. _altyapiyiBaslat)
  runApp(const AntrenorUygulamasi());
}

class AntrenorUygulamasi extends StatefulWidget {
  const AntrenorUygulamasi({super.key});

  @override
  State<AntrenorUygulamasi> createState() => _AntrenorUygulamasiDurumu();
}

class _AntrenorUygulamasiDurumu extends State<AntrenorUygulamasi> {
  final _veri = Veri();
  final _abonelik = Abonelik.ornek;

  late final Future<void> _veriHazir;
  final _mesajAnahtari = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Tema tercihi degisince tum uygulama yeniden cizilir
    _veri.addListener(_temayiUygula);
    _abonelik.addListener(_abonelikDegisti);
    _veriHazir = _veri.baslat();

    // Uygulama acikken gelen bildirim: Android sistem bildirimini
    // gostermiyor, kullaniciya biz haber veriyoruz
    Bildirim.onMesaj(_ekrandakiBildirim);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_altyapiyiBaslat()));
  }

  /// Agir yerel altyapi ilk kare cizildikten sonra, en ucuzdan en pahaliya
  /// dogru kuruluyor. Hepsi acilista pesin kurulunca ana is parcacigi
  /// saniyelerce kilitleniyor ve uygulama donuyordu.
  Future<void> _altyapiyiBaslat() async {
    await Bildirim.baslat();
    // Yerel hatirlatmalar: ucuz, sunucuya bagli degil
    await Hatirlatici.baslat();
    await Profil.ornek.yukle();
    await _veriHazir;
    await Bildirim.esitle(_veri.takipEdilen);

    await _abonelik.baslat();

    // Reklam kutuphanesi en pahalisi: WebView acip Play Services'e baglaniyor.
    // Premium kullanicida hic kurulmuyor; digerlerinde arayuz yerlestikten
    // sonra sessizce isiniyor, gerekirse ilk reklamda zaten kurulur.
    if (!_abonelik.premium) {
      await Future<void>.delayed(const Duration(seconds: 3));
      await Reklam.baslat();
    }
  }

  void _ekrandakiBildirim(
      String baslik, String govde, Map<String, dynamic> veri) {
    // Akista yeni kayit varsa gorunsun
    unawaited(_veri.baslat());
    _mesajAnahtari.currentState?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      backgroundColor: Renkler.yuzeyYuksek,
      behavior: SnackBarBehavior.floating,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(baslik,
              style: TextStyle(
                  color: Renkler.kurs,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(govde,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Renkler.metin, fontSize: 14)),
          ],
        ],
      ),
    ));
  }

  void _temayiUygula() {
    Renkler.paletiDegistir(_veri.koyuTema);
    if (mounted) setState(() {});
  }

  void _abonelikDegisti() {
    // Premium'a gecildiginde bellekteki reklam birakilir
    if (_abonelik.premium) Reklam.temizle();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _veri.removeListener(_temayiUygula);
    _abonelik.removeListener(_abonelikDegisti);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Renkler.paletiDegistir(_veri.koyuTema);
    return MaterialApp(
      title: 'Antrenör',
      scaffoldMessengerKey: _mesajAnahtari,
      debugShowCheckedModeBanner: false,
      theme: antrenorTemasi(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnaKabuk(veri: _veri),
    );
  }
}

/// Beş sekme: Anasayfa · Federasyonlar · Bilgi · Bildirimler · Kayıtlar
/// Ayarlar sekme yerine üst çubuktaki dişli simgesinde: günde bir kez
/// açılan bir ekran için sekme yeri harcamak yazık.
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
    if (hedef == 'ayarlar') {
      _ayarlaraGit();
      return;
    }
    final indeks = switch (hedef) {
      'federasyonlar' => 1,
      'bilgi' => 2,
      'bildirimler' => 3,
      'kayitlar' => 4,
      _ => 0,
    };
    setState(() => _sekme = indeks);
  }

  void _ayarlaraGit() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ayarlar')),
          body: SafeArea(
            child: AyarlarEkrani(
              veri: _veri,
              federasyonlaraGit: () {
                Navigator.of(context).pop();
                _sekmeyeGit('federasyonlar');
              },
            ),
          ),
        ),
      ));

  void _aramayaGit() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AramaEkrani(veri: _veri)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Anasayfa kendi başlığını sliver olarak taşır; diğer sekmelerde
      // sade bir başlık yeterli
      appBar: _sekme == 0
          ? null
          : AppBar(
              title: Text(_baslik(_sekme)),
              actions: [
                IconButton(
                  tooltip: 'Ara',
                  icon: const Icon(Icons.search),
                  onPressed: _aramayaGit,
                ),
                IconButton(
                  tooltip: 'Ayarlar',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _ayarlaraGit,
                ),
              ],
            ),
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
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Bilgi'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none),
              selectedIcon: Icon(Icons.notifications),
              label: 'Bildirimler'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Kayıtlar'),
        ],
      ),
    );
  }

  static String _baslik(int sekme) => switch (sekme) {
        1 => 'Federasyonlar',
        2 => 'Bilgi Deposu',
        3 => 'Bildirimler',
        _ => 'Kayıtlar',
      };

  Widget _govde() {
    if (_veri.yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_veri.hata != null && _veri.duyurular.isEmpty) {
      return _HataDurumu(mesaj: _veri.hata!, tekrar: _veri.baslat);
    }
    return switch (_sekme) {
      0 => Anasayfa(
          veri: _veri, sekmeyeGit: _sekmeyeGit, aramayaGit: _aramayaGit),
      1 => FederasyonlarEkrani(veri: _veri),
      2 => BilgiEkrani(veri: _veri),
      3 => BildirimlerEkrani(
          veri: _veri, federasyonlaraGit: () => _sekmeyeGit('federasyonlar')),
      _ => KaydedilenlerEkrani(veri: _veri),
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
