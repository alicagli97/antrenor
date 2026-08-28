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
    _dinleyiciyiBagla();
  }

  /// Android 13+ ve iOS'ta izin ister. İzin verilmezse abonelikler yine
  /// kaydedilir; kullanıcı sonradan izin verirse bildirimler gelmeye başlar.
  /// Tanitim videosu cekiminde sistem izin penceresi otomasyonu kilitliyor:
  /// pencere Flutter'in disinda, test kapatamiyor. Yalnizca o cekimde
  /// (--dart-define=TANITIM=true) izin istenmiyor.
  static const tanitimKipi = bool.fromEnvironment('TANITIM');

  static Future<bool> izinIste() async {
    if (!hazir || tanitimKipi) return false;
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

  static void Function(Map<String, dynamic> veri)? _dinleyici;
  static void Function(String baslik, String govde, Map<String, dynamic> veri)?
      _onMesaj;
  static bool _bagli = false;
  static bool _mesajaBagli = false;

  /// Uygulama ekrandayken gelen bildirim. Android bu durumda sistem
  /// bildirimini göstermiyor, mesajı yalnızca uygulamaya iletiyor; hiçbir şey
  /// yapılmazsa kullanıcı açısından "bildirim gelmedi" gibi görünüyor.
  static void onMesaj(
      void Function(String baslik, String govde, Map<String, dynamic> veri)
          geldi) {
    _onMesaj = geldi;
    _dinleyiciyiBagla();
  }

  /// Bildirime dokunulduğunda gelen veriyi dinler.
  /// `data.announcement_id` ile ilgili duyuruya gidilir.
  ///
  /// Firebase artık ilk kareden sonra kuruluyor; arayüz bundan önce dinlemek
  /// isterse istek saklanır ve altyapı hazır olunca bağlanır.
  static void dinle(void Function(Map<String, dynamic> veri) acildi) {
    _dinleyici = acildi;
    _dinleyiciyiBagla();
  }

  /// Her iki dinleyici birbirinden bağımsız bağlanır: hangisi önce
  /// kaydedilirse diğeri sonradan da bağlanabilsin.
  static void _dinleyiciyiBagla() {
    if (!hazir) return;
    final acildi = _bagli ? null : _dinleyici;
    final geldi = _mesajaBagli ? null : _onMesaj;

    if (acildi != null) {
      _bagli = true;
      FirebaseMessaging.onMessageOpenedApp.listen((m) => acildi(m.data));
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) acildi(m.data);
      });
    }
    if (geldi != null) {
      _mesajaBagli = true;
      FirebaseMessaging.onMessage.listen((m) {
        final b = m.notification;
        geldi(b?.title ?? 'Yeni duyuru', b?.body ?? '', m.data);
      });
    }
  }
}
