import 'package:flutter/material.dart';

import '../cekirdek/bildirim.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Bildirim iznini doğru anda ister: kullanıcı ilk federasyonu takibe
/// aldığında. Sistem penceresi bir kez çıkıyor ve reddedilirse geri dönüşü
/// zor olduğu için önce nedenini kendi dilimizle anlatıyoruz.
///
/// Ayarlar'a hiç girmeyen kullanıcı da böylece bildirimlerden haberdar olur.
Future<void> bildirimIzniSor(BuildContext context, Veri veri,
    {bool zorla = false}) async {
  if (!Bildirim.hazir) {
    if (zorla && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bildirim altyapısı bu sürümde kapalı')));
    }
    return;
  }
  if (!zorla && veri.bildirimSoruldu) return;

  final durum = await Bildirim.izinDurumu();
  final zatenVar = durum.name == 'authorized' || durum.name == 'provisional';
  if (zatenVar) {
    await veri.bildirimSorulduIsaretle();
    await Bildirim.esitle(veri.takipEdilen);
    if (zorla && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirimler zaten açık')));
    }
    return;
  }

  if (!context.mounted) return;
  final onay = await showModalBottomSheet<bool>(
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
              color: Renkler.kurs.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: Renkler.kurs, size: 22),
          ),
          const SizedBox(height: 16),
          Text('Kurs duyurularını kaçırma', style: Yazi.baslik),
          const SizedBox(height: 10),
          Text(
            'Takip ettiğin federasyonlarda yeni kurs, vize semineri veya '
            'talimat yayımlandığında sana haber verelim. Sadece seçtiğin '
            'federasyonlar için bildirim gider; başka hiçbir şey gönderilmez.',
            style: Yazi.govde.copyWith(height: 1.5),
          ),
          const SizedBox(height: 22),
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
                    backgroundColor: Renkler.kurs,
                    foregroundColor: Renkler.koyuMu
                        ? const Color(0xFF13181F)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(c, true),
                  child: Text('Bildirimleri aç',
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

  await veri.bildirimSorulduIsaretle();
  if (onay != true) return;

  final verildi = await Bildirim.izinIste();
  if (verildi) await Bildirim.esitle(veri.takipEdilen);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(verildi
        ? 'Bildirimler açıldı'
        : 'İzin verilmedi. Telefon ayarlarından sonra açabilirsin.'),
  ));
}
