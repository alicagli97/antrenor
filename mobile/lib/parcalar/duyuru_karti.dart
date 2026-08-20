import 'package:flutter/material.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';

/// Akıştaki tek duyuru kartı. Kaynak federasyon ve kategori her zaman görünür;
/// içeriğin resmî hâli federasyonun sitesinde olduğu için bağlantı korunur.
class DuyuruKarti extends StatelessWidget {
  final Duyuru duyuru;
  final bool takipte;
  final VoidCallback? onTap;

  const DuyuruKarti({
    super.key,
    required this.duyuru,
    this.takipte = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final renk = Renkler.kategoriRengi(duyuru.kategori);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Renkler.cizgi)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 13, color: renk),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    duyuru.etiketAdi,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Renkler.metinIkincil,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (takipte) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.push_pin, size: 12, color: Renkler.metinSolgun),
                ],
                const Spacer(),
                Text(
                  _tarih(duyuru.yayinTarihi),
                  style: const TextStyle(
                      color: Renkler.metinSolgun, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              duyuru.baslik,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Renkler.metin,
                fontSize: 15.5,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (duyuru.ozet.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                duyuru.ozet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Renkler.metinSolgun,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _Rozet(
                  metin: Renkler.kategoriAdi(duyuru.kategori),
                  renk: renk,
                ),
                if (duyuru.antrenorIcin) ...[
                  const SizedBox(width: 6),
                  const _Rozet(metin: 'Antrenör', renk: Renkler.kurs),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _tarih(DateTime? t) {
    if (t == null) return '';
    final fark = DateTime.now().difference(t);
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    if (fark.inHours < 24) return '${fark.inHours} sa önce';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
  }
}

class _Rozet extends StatelessWidget {
  final String metin;
  final Color renk;
  const _Rozet({required this.metin, required this.renk});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: renk.withValues(alpha: 0.35)),
        ),
        child: Text(
          metin,
          style: TextStyle(
            color: renk,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );
}
