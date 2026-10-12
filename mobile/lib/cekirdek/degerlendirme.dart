import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mağaza puanlama isteği.
///
/// Uygulamanın App Store'da tek değerlendirmesi var; puansız bir sayfa
/// indirmeyi belirgin şekilde düşürüyor. Bu yüzden kullanıcıdan puan
/// isteniyor — ama ilk açılışta değil, uygulamayı gerçekten kullandıktan
/// sonra.
///
/// Her iki mağazanın da kendi yerleşik penceresi kullanılıyor
/// (iOS: StoreKit, Android: Play In-App Review). Kullanıcı uygulamadan
/// çıkmıyor, biz de ne cevap verdiğini öğrenmiyoruz — mağazalar bunu
/// bilerek gizliyor ki geliştirici sonucu yönlendiremesin.
///
/// Mağazalar pencereyi göstermeme hakkını saklı tutuyor (iOS yılda en çok
/// üç kez). Bu yüzden "istedik" demek "gösterildi" demek değil; tekrar
/// istememek için yine de işaretliyoruz.
class Degerlendirme {
  Degerlendirme._();

  static const _acilisAnahtari = 'degerlendirme_acilis';
  static const _ilkGunAnahtari = 'degerlendirme_ilk_gun';
  static const _istendiAnahtari = 'degerlendirme_istendi';

  /// Kaç açılıştan sonra sorulacağı. İlk izlenimde sormak hem rahatsız edici
  /// hem de kullanıcının söyleyecek bir şeyi yokken soruyor.
  static const _gerekenAcilis = 3;

  /// Kurulumdan sonra en az kaç gün geçmeli.
  static const _gerekenGun = 2;

  /// Her açılışta çağrılır; sayacı ilerletir.
  static Future<void> acilisiSay() async {
    try {
      final kayit = await SharedPreferences.getInstance();
      final sayi = (kayit.getInt(_acilisAnahtari) ?? 0) + 1;
      await kayit.setInt(_acilisAnahtari, sayi);
      if (!kayit.containsKey(_ilkGunAnahtari)) {
        await kayit.setInt(
            _ilkGunAnahtari, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('degerlendirme sayaci yazilamadi: $e');
    }
  }

  /// Koşullar tuttuysa mağazanın puanlama penceresini açar.
  ///
  /// Sessizce başarısız olur: puan istemek hiçbir zaman kullanıcının
  /// akışını bozacak kadar önemli değil.
  static Future<void> belkiIste() async {
    try {
      final kayit = await SharedPreferences.getInstance();
      if (kayit.getBool(_istendiAnahtari) ?? false) return;

      final acilis = kayit.getInt(_acilisAnahtari) ?? 0;
      if (acilis < _gerekenAcilis) return;

      final ilk = kayit.getInt(_ilkGunAnahtari);
      if (ilk == null) return;
      final gecenGun = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ilk))
          .inDays;
      if (gecenGun < _gerekenGun) return;

      final arayuz = InAppReview.instance;
      if (!await arayuz.isAvailable()) return;

      await arayuz.requestReview();
      await kayit.setBool(_istendiAnahtari, true);
    } catch (e) {
      debugPrint('degerlendirme istenemedi: $e');
    }
  }
}
