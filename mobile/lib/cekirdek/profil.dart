import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hatirlatici.dart';

/// Antrenörün kendi durumu: branşı, kademesi ve vize bitiş tarihi.
///
/// Uygulamanın geri kalanı herkese aynı listeyi gösterir; burası kullanıcıya
/// özel olan tek yer. Tamamen cihazda saklanır, sunucuya gitmez.
///
/// Vize (lisans yenileme) tarihi girilince uygulama geri sayımı yürütür ve
/// son güne 60/30/7 gün kala telefonun kendi zamanlayıcısına hatırlatma
/// kurar. Kullanıcının elle bir şey yapması gerekmez.
class Profil extends ChangeNotifier {
  static final Profil ornek = Profil._();
  Profil._();

  static const kademeler = <int, String>{
    1: '1. Kademe (Yardımcı Antrenör)',
    2: '2. Kademe (Antrenör)',
    3: '3. Kademe (Kıdemli Antrenör)',
    4: '4. Kademe (Baş Antrenör)',
    5: '5. Kademe (Teknik Direktör)',
  };

  /// Son güne kaç gün kala hatırlatılacağı
  static const uyariGunleri = [60, 30, 7, 1];

  String? brans; // federasyon slug'ı
  int? kademe;
  DateTime? vizeBitis;

  bool get kurulu => brans != null && vizeBitis != null;

  /// Bugün dâhil kaç gün kaldı. Geçmişse negatif.
  int? get kalanGun {
    final b = vizeBitis;
    if (b == null) return null;
    final bugun = DateTime.now();
    return DateTime(b.year, b.month, b.day)
        .difference(DateTime(bugun.year, bugun.month, bugun.day))
        .inDays;
  }

  VizeDurumu get durum {
    final g = kalanGun;
    if (g == null) return VizeDurumu.bilinmiyor;
    if (g < 0) return VizeDurumu.gecti;
    if (g <= 30) return VizeDurumu.acil;
    if (g <= 90) return VizeDurumu.yaklasiyor;
    return VizeDurumu.rahat;
  }

  Future<void> yukle() async {
    final kayit = await SharedPreferences.getInstance();
    brans = kayit.getString('profil_brans');
    kademe = kayit.getInt('profil_kademe');
    final t = kayit.getString('profil_vize');
    vizeBitis = t == null ? null : DateTime.tryParse(t);
    notifyListeners();
  }

  Future<void> kaydet({
    required String brans,
    required int kademe,
    required DateTime vizeBitis,
  }) async {
    this.brans = brans;
    this.kademe = kademe;
    this.vizeBitis = vizeBitis;

    final kayit = await SharedPreferences.getInstance();
    await kayit.setString('profil_brans', brans);
    await kayit.setInt('profil_kademe', kademe);
    await kayit.setString('profil_vize', vizeBitis.toIso8601String());

    await _hatirlatmalariKur();
    notifyListeners();
  }

  Future<void> sil() async {
    final kayit = await SharedPreferences.getInstance();
    await kayit.remove('profil_brans');
    await kayit.remove('profil_kademe');
    await kayit.remove('profil_vize');
    for (final g in uyariGunleri) {
      await Hatirlatici.iptal('vize:$g');
    }
    brans = null;
    kademe = null;
    vizeBitis = null;
    notifyListeners();
  }

  /// Eski hatırlatmalar temizlenip yenileri kurulur; tarih değişince
  /// ortada yanlış bir uyarı kalmasın.
  Future<void> _hatirlatmalariKur() async {
    final bitis = vizeBitis;
    if (bitis == null) return;

    for (final g in uyariGunleri) {
      await Hatirlatici.iptal('vize:$g');
    }
    await Hatirlatici.izinIste();

    for (final g in uyariGunleri) {
      // Sabah dokuzda hatırlatmak, gece yarısı bildirimi göndermekten iyi
      final ne = DateTime(bitis.year, bitis.month, bitis.day, 9)
          .subtract(Duration(days: g));
      if (!ne.isAfter(DateTime.now())) continue;
      await Hatirlatici.kur(
        anahtar: 'vize:$g',
        baslik: 'Vize süreniz doluyor',
        metin: g == 1
            ? 'Vizenizin son günü yarın. Başvurunuzu tamamlayın.'
            : 'Vizenizin bitmesine $g gün kaldı.',
        ne: ne,
      );
    }
  }
}

enum VizeDurumu { bilinmiyor, rahat, yaklasiyor, acil, gecti }
