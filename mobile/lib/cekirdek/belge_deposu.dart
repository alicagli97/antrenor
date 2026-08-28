import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Mevzuat belgelerini cihaza indirip saklar.
///
/// Belge federasyonun kendi sunucusundan, kullanıcı istediği anda indirilir —
/// biz hiçbir belgeyi kendi sunucumuzda yayımlamıyoruz. İndirilen kopya
/// cihazda kalır: aynı belge ikinci kez açıldığında ağa çıkılmaz, uçak
/// modunda da açılır.
class BelgeDeposu {
  BelgeDeposu._();

  static Directory? _dizin;

  static Future<Directory> _klasor() async {
    final hazir = _dizin;
    if (hazir != null) return hazir;
    final kok = await getApplicationSupportDirectory();
    final d = Directory('${kok.path}/belgeler');
    if (!await d.exists()) await d.create(recursive: true);
    return _dizin = d;
  }

  /// Dosya adı URL'den türetiliyor: aynı belge her seferinde aynı yere düşsün,
  /// uzun ve bozuk karakterli adresler dosya sistemini zorlamasın.
  static String _ad(String url) =>
      '${sha1.convert(utf8.encode(url)).toString().substring(0, 20)}.pdf';

  static Future<File> _dosya(String url) async =>
      File('${(await _klasor()).path}/${_ad(url)}');

  /// Belge daha önce indirildiyse dosyayı döndürür.
  static Future<File?> yereldenAl(String url) async {
    try {
      final f = await _dosya(url);
      if (await f.exists() && await f.length() > 1024) return f;
    } catch (_) {}
    return null;
  }

  /// İndirir ve cihaza yazar. Zaten varsa ağa çıkmaz.
  ///
  /// [ilerleme] 0..1 arası; sunucu boyut bildirmezse çağrılmaz.
  static Future<File> getir(String url,
      {void Function(double)? ilerleme}) async {
    final hazir = await yereldenAl(url);
    if (hazir != null) return hazir;

    final istek = http.Request('GET', Uri.parse(url));
    final yanit = await http.Client().send(istek).timeout(
          const Duration(seconds: 45),
        );
    if (yanit.statusCode != 200) {
      throw 'Belge alınamadı (HTTP ${yanit.statusCode})';
    }

    final toplam = yanit.contentLength ?? 0;
    final parcalar = <int>[];
    var inen = 0;

    await for (final parca in yanit.stream) {
      parcalar.addAll(parca);
      inen += parca.length;
      if (toplam > 0 && ilerleme != null) ilerleme(inen / toplam);
    }

    // PDF olmayan bir sey indiyse (hata sayfasi, giris ekrani) goruntuleyici
    // bos ekran gosterirdi; bastaki imzaya bakip erken hata veriyoruz.
    if (parcalar.length < 5 ||
        String.fromCharCodes(parcalar.take(4)) != '%PDF') {
      throw 'Bu adres PDF döndürmedi';
    }

    final f = await _dosya(url);
    await f.writeAsBytes(parcalar, flush: true);
    return f;
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

  static Future<void> temizle() async {
    try {
      final d = await _klasor();
      if (await d.exists()) await d.delete(recursive: true);
      _dizin = null;
    } catch (e) {
      debugPrint('belge onbellegi silinemedi: $e');
    }
  }
}
