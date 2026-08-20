import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import 'federasyon_detay.dart';

/// Federasyonlar: 65 kurumun tamamı. Yıldız ile takibe alınır; takip edilenler
/// akışta öne çıkar ve bildirim gönderilir. Karta dokununca federasyonun
/// duyuru, takvim, mevzuat ve oyun kuralları sayfası açılır.
class FederasyonlarEkrani extends StatefulWidget {
  final Veri veri;
  const FederasyonlarEkrani({super.key, required this.veri});

  @override
  State<FederasyonlarEkrani> createState() => _FederasyonlarDurumu();
}

class _FederasyonlarDurumu extends State<FederasyonlarEkrani> {
  String _arama = '';
  bool _sadeceTakip = false;

  @override
  Widget build(BuildContext context) {
    final veri = widget.veri;
    final sorgu = _arama.toLowerCase();

    final liste = veri.federasyonlar.where((f) {
      if (_sadeceTakip && !veri.takipEdilen.contains(f.slug)) return false;
      if (sorgu.isEmpty) return true;
      return f.etiket.toLowerCase().contains(sorgu) ||
          f.ad.toLowerCase().contains(sorgu) ||
          f.branslar.any((b) => b.toLowerCase().contains(sorgu));
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            style: const TextStyle(color: Renkler.metin, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Branş ara — ör. yüzme, hentbol',
              hintStyle:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: Renkler.metinSolgun),
              filled: true,
              fillColor: Renkler.yuzey,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Renkler.cizgi),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Renkler.cizgi),
              ),
            ),
            onChanged: (d) => setState(() => _arama = d),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 14),
            FilterChip(
              label: Text('Takip ettiklerim (${veri.takipEdilen.length})'),
              selected: _sadeceTakip,
              onSelected: (d) => setState(() => _sadeceTakip = d),
              backgroundColor: Renkler.yuzey,
              selectedColor: Renkler.kurs.withValues(alpha: 0.16),
              checkmarkColor: Renkler.kurs,
              labelStyle: TextStyle(
                  color: _sadeceTakip ? Renkler.kurs : Renkler.metinIkincil,
                  fontSize: 12.5),
              side: BorderSide(
                  color: _sadeceTakip
                      ? Renkler.kurs.withValues(alpha: 0.4)
                      : Renkler.cizgi),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${liste.length} kurum',
                  style: const TextStyle(
                      color: Renkler.metinSolgun, fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: liste.length,
            itemBuilder: (_, i) {
              final f = liste[i];
              final takipte = veri.takipEdilen.contains(f.slug);
              return ListTile(
                title: Text(f.etiket,
                    style:
                        const TextStyle(color: Renkler.metin, fontSize: 15)),
                subtitle: Text(
                  [
                    if (f.olimpik) 'Olimpik',
                    if (f.para) 'Paralimpik',
                    '${f.duyuruSayisi} duyuru',
                  ].join(' · '),
                  style: const TextStyle(
                      color: Renkler.metinSolgun, fontSize: 12.5),
                ),
                trailing: IconButton(
                  icon: Icon(takipte ? Icons.star : Icons.star_border,
                      color: takipte ? Renkler.kurs : Renkler.metinSolgun,
                      size: 22),
                  tooltip: takipte ? 'Takibi bırak' : 'Takip et',
                  onPressed: () async {
                    await veri.takibiDegistir(f.slug);
                    if (mounted) setState(() {});
                  },
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        FederasyonDetay(veri: veri, federasyon: f))),
              );
            },
          ),
        ),
      ],
    );
  }
}
