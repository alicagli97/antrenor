import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';

/// Duyuru detayı. Özet gösterilir, tam metin için kaynağa yönlendirilir:
/// içeriğin resmî ve bağlayıcı hâli federasyonun kendi sitesindedir.
class DuyuruDetay extends StatelessWidget {
  final Duyuru duyuru;
  const DuyuruDetay({super.key, required this.duyuru});

  @override
  Widget build(BuildContext context) {
    final renk = Renkler.kategoriRengi(duyuru.kategori);
    return Scaffold(
      appBar: AppBar(
        title: Text(duyuru.etiketAdi, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.bookmark_border, color: Renkler.metinIkincil),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kaydetme yakında')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: renk.withValues(alpha: 0.35)),
              ),
              child: Text(Renkler.kategoriAdi(duyuru.kategori),
                  style: TextStyle(
                      color: renk, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Text(_tarih(duyuru.yayinTarihi),
                style: Yazi.kucuk),
          ]),
          const SizedBox(height: 14),
          Text(duyuru.baslik,
              style: TextStyle(
                  color: Renkler.metin,
                  fontSize: 21,
                  height: 1.3,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (duyuru.ozet.isNotEmpty)
            Text(duyuru.ozet,
                style: TextStyle(
                    color: Renkler.metinIkincil, fontSize: 15, height: 1.55)),
          const SizedBox(height: 26),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Renkler.yuzeyYuksek,
              foregroundColor: Renkler.metin,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Renkler.cizgi)),
            ),
            onPressed: () => launchUrl(Uri.parse(duyuru.url),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Kaynakta aç'),
          ),
          const SizedBox(height: 14),
          Text(
            'Duyurunun resmî ve bağlayıcı hâli ${duyuru.federasyonAdi} sitesindedir.',
            style: TextStyle(color: Renkler.metinSolgun, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _tarih(DateTime? t) => t == null
      ? ''
      : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}
