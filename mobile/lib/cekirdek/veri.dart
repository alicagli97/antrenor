import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'abonelik.dart';
import 'bildirim.dart';
import 'depo.dart';
import 'modeller.dart';

/// Veri kaynağı: GitHub Pages üzerinde yayınlanan statik JSON uçları.
/// Sunucu yok; uygulama dosyaları indirir, tercihleri yerelde saklar.
class Veri extends ChangeNotifier {
  static const kok = 'https://alicagli97.github.io/antrenor/api/v1';

  /// Ücretsiz sürümde takip edilebilecek federasyon sayısı
  static const ucretsizTakipSiniri = 1;

  bool get premium => Abonelik.ornek.premium;

  /// Yeni bir federasyon takibe alınabilir mi? (Zaten takiptekini bırakmak
  /// her zaman serbest; bu denetim yalnızca ekleme için çağrılır.)
  bool get takipEklenebilir =>
      premium || takipEdilen.length < ucretsizTakipSiniri;

  final List<Duyuru> duyurular = [];
  final List<Federasyon> federasyonlar = [];
  Afis afis = Afis.bos;

  /// Federasyon başına ayrıntılar (istendikçe indirilir)
  final Map<String, List<Duyuru>> _fedDuyurulari = {};
  final Map<String, Takvim?> _fedTakvimi = {};
  final Map<String, MevzuatKutuphanesi?> _fedMevzuati = {};

  Set<String> takipEdilen = {};
  bool koyuTema = true;
  bool bildirimSoruldu = false;
  bool pilSoruldu = false;
  bool yukleniyor = true;
  String? hata;
  DateTime? sonGuncelleme;

  /// Veri ağdan değil diskteki kopyadan geldiyse true; arayüz bunu
  /// kullanıcıya söyler, bayat veriyi taze gibi göstermeyiz.
  bool cevrimdisi = false;
  DateTime? onbellekTarihi;

  /// Kullanıcının kaydettiği duyuruların kimlikleri (cihazda saklanır)
  Set<String> kayitliDuyurular = {};

  Map<String, String> _etiketler = {};

  Future<void> baslat() async {
    yukleniyor = true;
    notifyListeners();
    try {
      await _tercihleriYukle();
      await _federasyonlariGetir();
      await Future.wait([_akisGetir(), _afisGetir()]);
      hata = null;
    } catch (e) {
      hata = 'Veri alınamadı. İnternet bağlantısını kontrol edin.';
    }
    yukleniyor = false;
    notifyListeners();
  }

  /// Ağdan indirir ve diske yazar. Bağlantı yoksa son inen kopyayı döndürür;
  /// böylece uygulama internetsiz de açılır, akış ve mevzuat okunabilir.
  Future<dynamic> _getir(String yol) async {
    try {
      final yanit = await http
          .get(Uri.parse('$kok/$yol'))
          .timeout(const Duration(seconds: 20));
      if (yanit.statusCode != 200) throw 'HTTP ${yanit.statusCode}';
      final metin = utf8.decode(yanit.bodyBytes);
      await Depo.yaz(yol, metin);
      cevrimdisi = false;
      return jsonDecode(metin);
    } catch (_) {
      final yedek = await Depo.oku(yol);
      if (yedek == null) rethrow;
      cevrimdisi = true;
      onbellekTarihi = await Depo.tarih(yol);
      return jsonDecode(yedek);
    }
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
    _akisOnbellegi.clear();
    _kategoriOnbellegi.clear();
    sonGuncelleme = DateTime.now();
  }

  Future<void> _afisGetir() async {
    try {
      afis = Afis.jsondan(await _getir('banner.json') as Map<String, dynamic>);
    } catch (_) {
      afis = Afis.bos; // afişin olmaması hata değil
    }
  }

  // --- Federasyon ayrıntıları --------------------------------------------

  Future<List<Duyuru>> fedDuyurulari(String slug) async {
    if (_fedDuyurulari.containsKey(slug)) return _fedDuyurulari[slug]!;
    try {
      final liste = await _getir('fed/$slug.json') as List;
      _fedDuyurulari[slug] = liste
          .map((e) => Duyuru.jsondan(e as Map<String, dynamic>,
              etiket: _etiketler[slug]))
          .toList();
    } catch (_) {
      _fedDuyurulari[slug] = const [];
    }
    return _fedDuyurulari[slug]!;
  }

  Future<Takvim?> fedTakvimi(String slug) async {
    if (_fedTakvimi.containsKey(slug)) return _fedTakvimi[slug];
    try {
      _fedTakvimi[slug] = Takvim.jsondan(
          await _getir('takvim/$slug.json') as Map<String, dynamic>);
    } catch (_) {
      _fedTakvimi[slug] = null;
    }
    return _fedTakvimi[slug];
  }

  Future<MevzuatKutuphanesi?> fedMevzuati(String slug) async {
    if (_fedMevzuati.containsKey(slug)) return _fedMevzuati[slug];
    try {
      _fedMevzuati[slug] = MevzuatKutuphanesi.jsondan(
          await _getir('kural/$slug.json') as Map<String, dynamic>);
    } catch (_) {
      _fedMevzuati[slug] = null;
    }
    return _fedMevzuati[slug];
  }

  String etiketAdi(String slug) => _etiketler[slug] ?? slug;

  Federasyon? federasyon(String slug) {
    for (final f in federasyonlar) {
      if (f.slug == slug) return f;
    }
    return null;
  }

  // --- Tercihler ----------------------------------------------------------

  Future<void> _tercihleriYukle() async {
    final kayit = await SharedPreferences.getInstance();
    takipEdilen = (kayit.getStringList('takip') ?? const []).toSet();
    koyuTema = kayit.getBool('koyu_tema') ?? true;
    bildirimSoruldu = kayit.getBool('bildirim_soruldu') ?? false;
    pilSoruldu = kayit.getBool('pil_soruldu') ?? false;
    kayitliDuyurular = await Depo.kayitliKimlikler();
  }

  // --- Kaydedilen duyurular ------------------------------------------------

  bool kayitli(Duyuru d) => kayitliDuyurular.contains(d.id);

  /// Kayıtlıysa çıkarır, değilse ekler. Dönen değer: artık kayıtlı mı?
  Future<bool> kaydiDegistir(Duyuru d) async {
    final sonuc = await Depo.kaydiDegistir(d);
    sonuc ? kayitliDuyurular.add(d.id) : kayitliDuyurular.remove(d.id);
    notifyListeners();
    return sonuc;
  }

  Future<List<Duyuru>> kaydedilenler() => Depo.kaydedilenler();

  /// Çevrimdışı arama: indirilen her şeyin içinde tam metin arar.
  /// Ağ isteği yapmaz, uçak modunda da çalışır.
  Future<List<AramaSonucu>> ara(String sorgu) async {
    final k = _kucult(sorgu.trim());
    if (k.length < 2) return const [];

    final sonuclar = <AramaSonucu>[];

    for (final d in duyurular) {
      if (_kucult('${d.baslik} ${d.ozet} ${d.federasyonAdi}').contains(k)) {
        sonuclar.add(AramaSonucu.duyuru(d));
      }
    }
    for (final liste in _kategoriOnbellegi.values) {
      for (final d in liste) {
        if (sonuclar.any((s) => s.duyuruKaydi?.id == d.id)) continue;
        if (_kucult('${d.baslik} ${d.ozet} ${d.federasyonAdi}').contains(k)) {
          sonuclar.add(AramaSonucu.duyuru(d));
        }
      }
    }
    for (final girdi in _fedTakvimi.entries) {
      for (final e in girdi.value?.etkinlikler ?? const <Etkinlik>[]) {
        if (_kucult('${e.ad} ${e.yer} ${e.brans}').contains(k)) {
          sonuclar.add(AramaSonucu.etkinlik(e, etiketAdi(girdi.key)));
        }
      }
    }
    for (final girdi in _fedMevzuati.entries) {
      for (final b in girdi.value?.belgeler ?? const <Belge>[]) {
        if (_kucult(b.baslik).contains(k)) {
          sonuclar.add(AramaSonucu.belge(b, etiketAdi(girdi.key)));
        }
      }
    }
    return sonuclar;
  }

  /// Türkçe'de `I`/`ı` ve `İ`/`i` çiftleri İngilizce kurallarıyla bozuluyor;
  /// arama "İSTANBUL" ile "istanbul"u eşleştirebilsin diye elle katlıyoruz.
  static String _kucult(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();

  Future<void> takibiDegistir(String slug) async {
    final takipteydi = takipEdilen.contains(slug);
    takipteydi ? takipEdilen.remove(slug) : takipEdilen.add(slug);
    // Takip edilenler akışta öne alınıyor; sıralama yeniden hesaplanmalı
    _akisOnbellegi.clear();
    for (final liste in _kategoriOnbellegi.values) {
      _sirala(liste);
    }

    final kayit = await SharedPreferences.getInstance();
    await kayit.setStringList('takip', takipEdilen.toList());

    // Bildirim aboneligi: cihaz dogrudan federasyonun konusuna abone olur,
    // sunucuda cihaz kimligi saklanmaz
    takipteydi
        ? await Bildirim.abonelikBirak(slug)
        : await Bildirim.aboneOl(slug);

    notifyListeners();
  }

  /// Bildirim izni bir kez sorulur; kullanıcı reddetse de tekrar tekrar
  /// sorulmaz (Ayarlar'dan istediğinde açabilir).
  Future<void> bildirimSorulduIsaretle() async {
    if (bildirimSoruldu) return;
    bildirimSoruldu = true;
    final kayit = await SharedPreferences.getInstance();
    await kayit.setBool('bildirim_soruldu', true);
  }

  /// Pil kısıtı uyarısı bir kez gösterilir; kullanıcı yok sayarsa
  /// tekrar tekrar rahatsız edilmez (Ayarlar'dan her zaman açılabilir).
  Future<void> pilSorulduIsaretle() async {
    if (pilSoruldu) return;
    pilSoruldu = true;
    final kayit = await SharedPreferences.getInstance();
    await kayit.setBool('pil_soruldu', true);
  }

  Future<void> temayiDegistir(bool koyu) async {
    koyuTema = koyu;
    final kayit = await SharedPreferences.getInstance();
    await kayit.setBool('koyu_tema', koyu);
    notifyListeners();
  }

  // --- Akış ve süzgeçler --------------------------------------------------

  /// Süzülmüş ve sıralanmış akış, kategori başına bir kez hesaplanır.
  /// Eskiden her yeniden çizimde 300 kayıt yeniden sıralanıyordu.
  final Map<String, List<Duyuru>> _akisOnbellegi = {};

  /// Kategori uçları (her biri 200 kayıt). Açılış akışı yalnızca son 300
  /// kaydı taşıdığı için, ondan süzmek bir kategoriden avuç dolusu sonuç
  /// veriyordu: 250 kurs duyurusu varken akışta 3 tanesi görünüyordu.
  final Map<String, List<Duyuru>> _kategoriOnbellegi = {};

  Future<List<Duyuru>> kategoriAkisi(String kategori) async {
    if (kategori == 'tumu') return akis();
    final hazir = _kategoriOnbellegi[kategori];
    if (hazir != null) return hazir;

    List<Duyuru> liste;
    try {
      final ham = await _getir('category/$kategori.json') as List;
      liste = ham
          .map((e) {
            final j = e as Map<String, dynamic>;
            return Duyuru.jsondan(j, etiket: _etiketler[j['federation']]);
          })
          .toList();
    } catch (_) {
      // Bağlantı yoksa elimizdeki akıştan süzmek hiç yoktan iyidir
      liste = akis(kategori: kategori);
    }
    _sirala(liste);
    _kategoriOnbellegi[kategori] = liste;
    return liste;
  }

  /// Takip edilenler öne, sonra tarihe göre yeniden eskiye
  void _sirala(List<Duyuru> liste) {
    liste.sort((a, b) {
      if (takipEdilen.isNotEmpty) {
        final fark = (takipEdilen.contains(a.federasyon) ? 0 : 1) -
            (takipEdilen.contains(b.federasyon) ? 0 : 1);
        if (fark != 0) return fark;
      }
      return (b.yayinTarihi ?? DateTime(2000))
          .compareTo(a.yayinTarihi ?? DateTime(2000));
    });
  }

  List<Duyuru> akis({String kategori = 'tumu'}) {
    final hazir = _akisOnbellegi[kategori];
    if (hazir != null) return hazir;

    final liste = duyurular
        .where((d) => kategori == 'tumu' || d.kategori == kategori)
        .toList();
    if (takipEdilen.isNotEmpty) {
      liste.sort((a, b) {
        final fark = (takipEdilen.contains(a.federasyon) ? 0 : 1) -
            (takipEdilen.contains(b.federasyon) ? 0 : 1);
        if (fark != 0) return fark;
        return (b.yayinTarihi ?? DateTime(2000))
            .compareTo(a.yayinTarihi ?? DateTime(2000));
      });
    }
    _akisOnbellegi[kategori] = liste;
    return liste;
  }

  /// Bildirimler sekmesi: seçili federasyonların duyuruları — akışta kalmayan
  /// eski kayıtlar dâhil (her federasyonun kendi dosyasından geçmiş alınır).
  Future<List<Duyuru>> takipEdilenlerinGecmisi() async {
    if (takipEdilen.isEmpty) return const [];
    final hepsi = <String, Duyuru>{};
    for (final slug in takipEdilen) {
      for (final d in await fedDuyurulari(slug)) {
        hepsi[d.id] = d;
      }
    }
    for (final d in duyurular) {
      if (takipEdilen.contains(d.federasyon)) hepsi[d.id] = d;
    }
    final liste = hepsi.values.toList()
      ..sort((a, b) => (b.yayinTarihi ?? DateTime(2000))
          .compareTo(a.yayinTarihi ?? DateTime(2000)));
    return liste;
  }
}
