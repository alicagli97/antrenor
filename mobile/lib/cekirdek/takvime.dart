import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

import 'modeller.dart';

/// Federasyon etkinliğini telefonun kendi takvimine yazar.
///
/// Uygulama takvim verisini okumaz, yalnızca sistem takvim ekranını
/// önceden doldurulmuş olarak açar; onay kullanıcıda kalır.
class Takvime {
  Takvime._();

  static Future<bool> etkinlikEkle(Etkinlik e, {String kaynak = ''}) async {
    final baslangic = e.tarih;
    if (baslangic == null) return false;

    // Saat bilgisi gelmiyor; gün boyu etkinlik olarak yazmak yanlış saat
    // göstermekten dürüst
    final gun = DateTime(baslangic.year, baslangic.month, baslangic.day);

    final aciklama = [
      if (e.brans.isNotEmpty) 'Branş: ${e.brans}',
      if (kaynak.isNotEmpty) 'Kaynak: $kaynak',
      'Antrenör uygulamasından eklendi',
    ].join('\n');

    try {
      return await Add2Calendar.addEvent2Cal(Event(
        title: e.ad,
        description: aciklama,
        location: e.yer,
        startDate: gun,
        endDate: gun.add(const Duration(hours: 23, minutes: 59)),
        allDay: true,
      ));
    } catch (hata) {
      debugPrint('takvime eklenemedi: $hata');
      return false;
    }
  }
}
