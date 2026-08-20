import 'package:flutter/material.dart';

import 'cekirdek/tema.dart';
import 'cekirdek/veri.dart';
import 'ekranlar/anasayfa.dart';
import 'ekranlar/federasyon_secimi.dart';
import 'ekranlar/kurslar.dart';
import 'ekranlar/mevzuat.dart';
import 'ekranlar/profil.dart';
import 'ekranlar/takvim.dart';

void main() => runApp(const AntrenorUygulamasi());

class AntrenorUygulamasi extends StatelessWidget {
  const AntrenorUygulamasi({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Antrenör',
        debugShowCheckedModeBanner: false,
        theme: antrenorTemasi(),
        home: const AnaKabuk(),
      );
}

/// Beş sekmeli ana kabuk: Anasayfa · Kurslar · Takvim · Mevzuat · Profil
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key});

  @override
  State<AnaKabuk> createState() => _AnaKabukDurumu();
}

class _AnaKabukDurumu extends State<AnaKabuk> {
  final _veri = Veri();
  int _sekme = 0;

  static const _basliklar = [
    'ANTRENÖR',
    'Kurslar',
    'Takvim',
    'Mevzuat',
    'Profil',
  ];

  @override
  void initState() {
    super.initState();
    _veri.addListener(_yenile);
    _veri.baslat();
  }

  void _yenile() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _veri.removeListener(_yenile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_basliklar[_sekme]),
        actions: [
          if (_sekme == 0)
            IconButton(
              icon: const Icon(Icons.tune, color: Renkler.metinIkincil),
              tooltip: 'Federasyonlarım',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FederasyonSecimi(veri: _veri))),
            ),
        ],
      ),
      body: _govde(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Anasayfa'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Kurslar'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Takvim'),
          NavigationDestination(
              icon: Icon(Icons.gavel_outlined),
              selectedIcon: Icon(Icons.gavel),
              label: 'Mevzuat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }

  Widget _govde() {
    if (_veri.yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_veri.hata != null && _veri.duyurular.isEmpty) {
      return _HataDurumu(mesaj: _veri.hata!, tekrar: _veri.baslat);
    }
    return switch (_sekme) {
      0 => Anasayfa(veri: _veri),
      1 => KurslarEkrani(veri: _veri),
      2 => TakvimEkrani(veri: _veri),
      3 => MevzuatEkrani(veri: _veri),
      _ => ProfilEkrani(veri: _veri),
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
              const Icon(Icons.cloud_off,
                  size: 42, color: Renkler.metinSolgun),
              const SizedBox(height: 14),
              Text(mesaj,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Renkler.metinIkincil, fontSize: 14, height: 1.4)),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: tekrar,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Renkler.metin,
                    side: const BorderSide(color: Renkler.cizgi)),
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
}
