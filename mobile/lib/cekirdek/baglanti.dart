import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dış bağlantıları güvenli biçimde açar.
///
/// Uygulamadaki adreslerin tamamı dışarıdan geliyor: federasyon sitelerinden
/// derlenen duyuru ve belge bağlantıları ile sunucudan yönetilen afiş. Bu
/// adresler doğrulanmadan açılırsa `intent://`, `javascript:` veya `file://`
/// gibi bir şema araya sokularak kullanıcı istenmeyen bir yere yönlendirilebilir
/// ya da başka bir uygulama tetiklenebilir. Yalnızca http/https geçiyor.
class Baglanti {
  static const _izinliSemalar = {'http', 'https'};

  static bool guvenli(String adres) {
    final uri = Uri.tryParse(adres.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return _izinliSemalar.contains(uri.scheme.toLowerCase());
  }

  /// Adresi tarayıcıda açar. Açılamazsa veya adres güvenli değilse
  /// kullanıcıya kısa bir bilgi verir ve sessizce vazgeçer.
  static Future<void> ac(BuildContext context, String adres) async {
    final mesajci = ScaffoldMessenger.maybeOf(context);

    if (!guvenli(adres)) {
      mesajci?.showSnackBar(
          const SnackBar(content: Text('Bu bağlantı açılamıyor')));
      return;
    }

    var acildi = false;
    try {
      acildi = await launchUrl(Uri.parse(adres.trim()),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      acildi = false;
    }
    if (!acildi) {
      mesajci?.showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı')));
    }
  }
}
