import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'modeller.dart';

/// Veri kaynağı: GitHub Pages üzerinde yayınlanan statik JSON uçları.
/// Sunucu yok; uygulama dosyaları indirir, yerelde saklar ve çevrimdışı okur.
class Veri extends ChangeNotifier {
  static const kok = 'https://alicagli97.github.io/antrenor/api/v1';

  final List<Duyuru> duyurular = [];
  final List<Federasyon> federasyonlar = [];
  final List<Takvim> takvimler = [];
  final List<MevzuatKutuphanesi> mevzuat = [];

  Set<String> takipEdilen = {};
  bool yukleniyor = true;
  String? hata;
  DateTime? sonGuncelleme;

  Map<String, String> _etiketler = {}; // slug -> görünen ad

  Future<void> baslat() async {
    yukleniyor = true;
    notifyListeners();
    try {
      await _takipYukle();
      await Future.wait([_federasyonlariGetir(), _akisGetir()]);
      hata = null;
    } catch (e) {
      hata = 'Veri alınamadı: $e';
    }
    yukleniyor = false;
    notifyListeners();
  }

  Future<dynamic> _getir(String yol) async {
    final yanit = await http
        .get(Uri.parse('$kok/$yol'))
        .timeout(const Duration(seconds: 20));
    if (yanit.statusCode != 200) {
      throw 'HTTP ${yanit.statusCode}';
    }
    return jsonDecode(utf8.decode(yanit.bodyBytes));
  }

  Future<void> _federasyonlariGetir() async {
    final liste = await _getir('federations.json') as List;
    federasyonlar
      ..clear()
      ..addAll(liste.map((e) => Federasyon.jsondan(e as Map<String, dynamic>)));
    federasyonlar.sort((a, b) => a.etiket.compareTo(b.etiket));
    _etiketler = {for (final f in federasyonlar) f.slug: f.etiket};
  }

  Future<void> _akisGetir() async {
    final liste = await _getir('feed.json') as List;
    duyurular
      ..clear()
      ..addAll(liste.map((e) {
        final j = e as Map<String, dynamic>;
        return Duyuru.jsondan(j, etiket: _etiketler[j['federation']]);
      }));
    sonGuncelleme = DateTime.now();
  }

  Future<void> takvimleriGetir() async {
    if (takvimler.isNotEmpty) return;
    final veri = await _getir('calendars.json') as Map<String, dynamic>;
    takvimler
      ..clear()
      ..addAll((veri['calendars'] as List)
          .map((e) => Takvim.jsondan(e as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> mevzuatGetir() async {
    if (mevzuat.isNotEmpty) return;
    final veri = await _getir('rules.json') as Map<String, dynamic>;
    mevzuat
      ..clear()
      ..addAll((veri['libraries'] as List)
          .map((e) => MevzuatKutuphanesi.jsondan(e as Map<String, dynamic>)));
    notifyListeners();
  }

  String etiketAdi(String slug) => _etiketler[slug] ?? slug;

  // --- Takip -----------------------------------------------------------

  Future<void> _takipYukle() async {
    final kayit = await SharedPreferences.getInstance();
    takipEdilen = (kayit.getStringList('takip') ?? const []).toSet();
  }

  Future<void> takibiDegistir(String slug) async {
    takipEdilen.contains(slug)
        ? takipEdilen.remove(slug)
        : takipEdilen.add(slug);
    final kayit = await SharedPreferences.getInstance();
    await kayit.setStringList('takip', takipEdilen.toList());
    notifyListeners();
  }

  // --- Filtreler -------------------------------------------------------

  /// Anasayfa akışı: takip edilenler varsa onlar önce gelir.
  List<Duyuru> akis({String? kategori}) {
    var liste = duyurular.where((d) {
      if (kategori != null && kategori != 'tumu' && d.kategori != kategori) {
        return false;
      }
      return true;
    }).toList();

    if (takipEdilen.isNotEmpty) {
      liste.sort((a, b) {
        final aTakip = takipEdilen.contains(a.federasyon) ? 0 : 1;
        final bTakip = takipEdilen.contains(b.federasyon) ? 0 : 1;
        if (aTakip != bTakip) return aTakip - bTakip;
        return (b.yayinTarihi ?? DateTime(2000))
            .compareTo(a.yayinTarihi ?? DateTime(2000));
      });
    }
    return liste;
  }

  List<Duyuru> get kurslar =>
      duyurular.where((d) => d.antrenorIcin || d.kategori == 'kurs').toList();
}
