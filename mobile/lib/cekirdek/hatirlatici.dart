import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzveri;
import 'package:timezone/timezone.dart' as tz;

/// Cihazda kurulan hatırlatmalar.
///
/// Sunucuyla ilgisi yok: bildirim telefonun kendi zamanlayıcısına yazılır,
/// uçak modunda bile çalışır. Kurs başvurusunun son günü veya bir müsabaka
/// tarihi yaklaşınca kullanıcıyı uyarmak için.
class Hatirlatici {
  Hatirlatici._();

  static final _eklenti = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  static const _kanal = AndroidNotificationChannel(
    'hatirlatma',
    'Hatırlatmalar',
    description: 'Kurduğunuz kurs, vize ve etkinlik hatırlatmaları',
    importance: Importance.high,
  );

  static Future<void> baslat() async {
    if (_hazir) return;
    try {
      tzveri.initializeTimeZones();
      // Kullanıcı kitlesi Türkiye; saat dilimi bulunamazsa yerel kalır
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}

      await _eklenti.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      await _eklenti
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_kanal);

      _hazir = true;
    } catch (e) {
      debugPrint('hatirlatici baslatilamadi: $e');
    }
  }

  /// iOS'ta izin ayrı istenir; Android'de POST_NOTIFICATIONS zaten alınıyor.
  static Future<bool> izinIste() async {
    await baslat();
    try {
      final ios = _eklenti.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      final android = _eklenti.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// [ne] zamanı geçmişse hatırlatma kurulmaz ve false döner.
  static Future<bool> kur({
    required String anahtar,
    required String baslik,
    required String metin,
    required DateTime ne,
  }) async {
    await baslat();
    if (!ne.isAfter(DateTime.now())) return false;

    final kimlik = anahtar.hashCode & 0x7fffffff;
    try {
      await _eklenti.zonedSchedule(
        kimlik,
        baslik,
        metin,
        tz.TZDateTime.from(ne, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kanal.id,
            _kanal.name,
            channelDescription: _kanal.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Tam saatli alarm ayrı izin ister; dakikalık sapma bizim için sorun
        // değil, izin istemek gereksiz sürtünme olurdu
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('hatirlatma kurulamadi: $e');
      return false;
    }

    await _kaydet(anahtar, baslik, ne);
    return true;
  }

  static Future<void> iptal(String anahtar) async {
    await baslat();
    try {
      await _eklenti.cancel(anahtar.hashCode & 0x7fffffff);
    } catch (_) {}
    final kayit = await SharedPreferences.getInstance();
    final ham = List<String>.from(kayit.getStringList(_anahtar) ?? const []);
    ham.removeWhere((s) {
      try {
        return (jsonDecode(s) as Map<String, dynamic>)['anahtar'] == anahtar;
      } catch (_) {
        return false;
      }
    });
    await kayit.setStringList(_anahtar, ham);
  }

  // --- Kurulmuş hatırlatmaların listesi ------------------------------------

  static const _anahtar = 'hatirlatmalar';

  static Future<void> _kaydet(String anahtar, String baslik, DateTime ne) async {
    final kayit = await SharedPreferences.getInstance();
    final ham = List<String>.from(kayit.getStringList(_anahtar) ?? const []);
    ham.removeWhere((s) {
      try {
        return (jsonDecode(s) as Map<String, dynamic>)['anahtar'] == anahtar;
      } catch (_) {
        return false;
      }
    });
    ham.add(jsonEncode({
      'anahtar': anahtar,
      'baslik': baslik,
      'ne': ne.toIso8601String(),
    }));
    await kayit.setStringList(_anahtar, ham);
  }

  /// Zamanı geçmişleri ayıklayarak, yakından uzağa sıralı döner.
  static Future<List<Hatirlatma>> liste() async {
    final kayit = await SharedPreferences.getInstance();
    final ham = kayit.getStringList(_anahtar) ?? const [];
    final simdi = DateTime.now();
    final liste = <Hatirlatma>[];
    final kalan = <String>[];

    for (final s in ham) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final ne = DateTime.parse(j['ne'] as String);
        if (ne.isBefore(simdi)) continue; // geçmiş kayıt tutulmaz
        liste.add(Hatirlatma(
          anahtar: j['anahtar'] as String,
          baslik: j['baslik'] as String,
          ne: ne,
        ));
        kalan.add(s);
      } catch (_) {}
    }

    if (kalan.length != ham.length) {
      await kayit.setStringList(_anahtar, kalan);
    }
    liste.sort((a, b) => a.ne.compareTo(b.ne));
    return liste;
  }

  static Future<Set<String>> kuruluAnahtarlar() async =>
      (await liste()).map((h) => h.anahtar).toSet();
}

class Hatirlatma {
  final String anahtar;
  final String baslik;
  final DateTime ne;

  const Hatirlatma({
    required this.anahtar,
    required this.baslik,
    required this.ne,
  });
}
