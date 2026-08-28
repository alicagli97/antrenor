import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modeller.dart';

/// Cihaz üzerindeki kalıcı depo.
///
/// İki işi var:
///  * Sunucudan inen JSON'u diske yazmak — böylece uygulama internet
///    olmadan da açılır, akış ve federasyon listesi görünür.
///  * Kullanıcının kaydettiği duyuruları saklamak — bunlar tamamen
///    cihazda durur, sunucuya gitmez ve çevrimdışı okunur.
class Depo {
  Depo._();

  static Directory? _dizin;

  static Future<Directory> _klasor() async {
    final hazir = _dizin;
    if (hazir != null) return hazir;
    final kok = await getApplicationSupportDirectory();
    final d = Directory('${kok.path}/onbellek');
    if (!await d.exists()) await d.create(recursive: true);
    return _dizin = d;
  }

  /// Uç adını dosya adına çevirir: `fed/atletizm.json` -> `fed_atletizm.json`
  static String _dosyaAdi(String yol) => yol.replaceAll('/', '_');

  static Future<void> yaz(String yol, String icerik) async {
    try {
      final d = await _klasor();
      await File('${d.path}/${_dosyaAdi(yol)}').writeAsString(icerik);
    } catch (_) {
      // Disk dolu veya izin yoksa önbellek olmaz; uygulama yine çalışır
    }
  }

  static Future<String?> oku(String yol) async {
    try {
      final dosya = File('${(await _klasor()).path}/${_dosyaAdi(yol)}');
      return await dosya.exists() ? await dosya.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  /// Önbelleğin ne zaman yazıldığı — "çevrimdışı, 3 saat önceki veri"
  /// gibi dürüst bir bilgi gösterebilmek için.
  static Future<DateTime?> tarih(String yol) async {
    try {
      final dosya = File('${(await _klasor()).path}/${_dosyaAdi(yol)}');
      return await dosya.exists() ? (await dosya.stat()).modified : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> temizle() async {
    try {
      final d = await _klasor();
      if (await d.exists()) await d.delete(recursive: true);
      _dizin = null;
    } catch (_) {}
  }

  static Future<int> boyut() async {
    try {
      final d = await _klasor();
      if (!await d.exists()) return 0;
      var toplam = 0;
      await for (final e in d.list()) {
        if (e is File) toplam += await e.length();
      }
      return toplam;
    } catch (_) {
      return 0;
    }
  }

  // --- Kaydedilen duyurular ------------------------------------------------

  static const _kayitAnahtari = 'kaydedilenler';

  /// Duyurunun tamamı saklanır; sunucudan düşse bile kullanıcı okumaya
  /// devam edebilsin diye yalnızca kimliği tutmak yetmez.
  static Future<List<Duyuru>> kaydedilenler() async {
    final kayit = await SharedPreferences.getInstance();
    final ham = kayit.getStringList(_kayitAnahtari) ?? const [];
    final liste = <Duyuru>[];
    for (final satir in ham) {
      try {
        liste.add(Duyuru.jsondan(jsonDecode(satir) as Map<String, dynamic>));
      } catch (_) {
        // Bozuk kayıt varsa atlanır, listenin tamamı çöpe gitmesin
      }
    }
    return liste;
  }

  static Future<Set<String>> kayitliKimlikler() async {
    final kayit = await SharedPreferences.getInstance();
    final ham = kayit.getStringList(_kayitAnahtari) ?? const [];
    final kimlikler = <String>{};
    for (final satir in ham) {
      try {
        final id = (jsonDecode(satir) as Map<String, dynamic>)['id'];
        if (id is String) kimlikler.add(id);
      } catch (_) {}
    }
    return kimlikler;
  }

  /// Kayıtlıysa çıkarır, değilse ekler. Dönen değer: kayıtlı mı?
  static Future<bool> kaydiDegistir(Duyuru d) async {
    final kayit = await SharedPreferences.getInstance();
    final ham = List<String>.from(kayit.getStringList(_kayitAnahtari) ?? const []);

    var bulundu = false;
    ham.removeWhere((satir) {
      try {
        if ((jsonDecode(satir) as Map<String, dynamic>)['id'] == d.id) {
          bulundu = true;
          return true;
        }
      } catch (_) {}
      return false;
    });

    if (!bulundu) ham.insert(0, jsonEncode(_duyuruyuYaz(d)));
    await kayit.setStringList(_kayitAnahtari, ham);
    return !bulundu;
  }

  static Map<String, dynamic> _duyuruyuYaz(Duyuru d) => {
        'id': d.id,
        'federation': d.federasyon,
        'federation_name': d.federasyonAdi,
        'federation_short': d.etiketAdi,
        'title': d.baslik,
        'url': d.url,
        'summary': d.ozet,
        'image': d.gorsel,
        'category': d.kategori,
        'tags': d.etiketler,
        'published_at': d.yayinTarihi?.toIso8601String(),
      };
}
