import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Bildirim altyapısı — Firebase Cloud Messaging, konu (topic) aboneliğiyle.
///
/// Neden konu: kullanıcı bir federasyonu takibe aldığında cihaz doğrudan
/// `fed_<slug>` konusuna abone oluyor. Sunucuda cihaz kimliği saklanmıyor,
/// böylece "kişisel veri toplanmıyor" beyanı bozulmuyor.
class Bildirim {
  static bool hazir = false;

  /// Uygulama açılışında bir kez çağrılır. Firebase yapılandırılmamışsa
  /// sessizce devre dışı kalır; uygulamanın kalanı çalışmaya devam eder.
  static Future<void> baslat() async {
    try {
      await Firebase.initializeApp();
      hazir = true;
    } catch (e) {
      hazir = false;
      debugPrint('Bildirim altyapısı kapalı: $e');
    }
  }

  /// Android 13+ ve iOS'ta izin ister. İzin verilmezse abonelikler yine
  /// kaydedilir; kullanıcı sonradan izin verirse bildirimler gelmeye başlar.
  static Future<bool> izinIste() async {
    if (!hazir) return false;
    final ayar = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return ayar.authorizationStatus == AuthorizationStatus.authorized ||
        ayar.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<AuthorizationStatus> izinDurumu() async {
    if (!hazir) return AuthorizationStatus.notDetermined;
    final ayar = await FirebaseMessaging.instance.getNotificationSettings();
    return ayar.authorizationStatus;
  }

  static String konu(String slug) => 'fed_$slug';

  static Future<void> aboneOl(String slug) async {
    if (!hazir) return;
    await FirebaseMessaging.instance.subscribeToTopic(konu(slug));
  }

  static Future<void> abonelikBirak(String slug) async {
    if (!hazir) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic(konu(slug));
  }

  /// Takip listesiyle abonelikleri eşitler (uygulama açılışında).
  static Future<void> esitle(Set<String> takipEdilen) async {
    if (!hazir) return;
    for (final slug in takipEdilen) {
      await aboneOl(slug);
    }
  }

  /// Bildirime dokunulduğunda gelen veriyi dinler.
  /// `data.announcement_id` ile ilgili duyuruya gidilir.
  static void dinle(void Function(Map<String, dynamic> veri) acildi) {
    if (!hazir) return;
    FirebaseMessaging.onMessageOpenedApp.listen((m) => acildi(m.data));
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) acildi(m.data);
    });
  }
}
