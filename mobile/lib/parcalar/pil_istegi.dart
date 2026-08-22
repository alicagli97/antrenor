import 'package:flutter/material.dart';

import '../cekirdek/pil.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Pil kısıtını kaldırma isteği.
///
/// Bildirim izni alındıktan hemen sonra gösterilir: izin verilmiş ama telefon
/// uygulamayı arka planda durduruyorsa bildirimler yine gelmez. Kullanıcı
/// bunu ancak birkaç gün sonra fark eder, o yüzden baştan hallediyoruz.
///
/// Tek dokunuşlu sistem muafiyet penceresi bilerek kullanılmıyor; gerekçesi
/// [Pil] içinde ve MainActivity'de yazılı (mağaza politikası).
Future<void> pilIzniSor(BuildContext context, Veri veri,
    {bool zorla = false}) async {
  if (!Pil.desteklenir) return;
  if (!zorla && veri.pilSoruldu) return;

  if (await Pil.muafMi()) {
    await veri.pilSorulduIsaretle();
    if (zorla && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Uygulama zaten pil kısıtından muaf')));
    }
    return;
  }

  if (!context.mounted) return;
  final ac = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Renkler.yuzey,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: Renkler.cizgiParlak,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Renkler.takvim.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.battery_saver_rounded,
                color: Renkler.takvim, size: 22),
          ),
          const SizedBox(height: 16),
          Text('Son bir adım', style: Yazi.baslik),
          const SizedBox(height: 10),
          Text(
            'Telefonun pil tasarrufu, uygulamaları arka planda durdurabiliyor. '
            'Durdurulursa bildirim izni açık olsa bile duyurular sana '
            'ulaşmaz ya da saatler sonra gelir.',
            style: Yazi.govde.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Renkler.yuzeyYuksek,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Renkler.cizgi),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 17, color: Renkler.metinSolgun),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Açılan ekranda:  Pil  →  Kısıtlanmamış',
                    style: Yazi.govde.copyWith(
                        color: Renkler.metin,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Renkler.metinIkincil,
                  ),
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Şimdi değil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Renkler.takvim,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text('Ayarları aç',
                      style: Yazi.govde.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Renkler.koyuMu
                              ? const Color(0xFF13181F)
                              : Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  await veri.pilSorulduIsaretle();
  if (ac != true) return;

  final acildi = await Pil.ayarlariAc();
  if (!acildi && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ayarlar açılamadı. Telefon ayarlarından Uygulamalar → '
          'Antrenör → Pil bölümüne bakabilirsin.'),
    ));
  }
}
