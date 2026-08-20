import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Federasyon takibi. Seçilenler akışta başa gelir ve (bildirim eklendiğinde)
/// o federasyonun konusuna abone olunur.
class FederasyonSecimi extends StatefulWidget {
  final Veri veri;
  const FederasyonSecimi({super.key, required this.veri});

  @override
  State<FederasyonSecimi> createState() => _FederasyonSecimiDurumu();
}

class _FederasyonSecimiDurumu extends State<FederasyonSecimi> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final sorgu = _arama.toLowerCase();
    final liste = widget.veri.federasyonlar.where((f) {
      if (sorgu.isEmpty) return true;
      return f.etiket.toLowerCase().contains(sorgu) ||
          f.ad.toLowerCase().contains(sorgu) ||
          f.branslar.any((b) => b.toLowerCase().contains(sorgu));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Federasyonlarım'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
        ),
      ),
      body: ListView.builder(
        itemCount: liste.length,
        itemBuilder: (_, i) {
          final f = liste[i];
          final takipte = widget.veri.takipEdilen.contains(f.slug);
          return ListTile(
            title: Text(f.etiket,
                style: const TextStyle(color: Renkler.metin, fontSize: 14.5)),
            subtitle: Text(
              [
                if (f.olimpik) 'Olimpik',
                if (f.para) 'Paralimpik',
                '${f.duyuruSayisi} duyuru',
              ].join(' · '),
              style:
                  const TextStyle(color: Renkler.metinSolgun, fontSize: 12.5),
            ),
            trailing: Icon(
              takipte ? Icons.check_circle : Icons.add_circle_outline,
              color: takipte ? Renkler.takvim : Renkler.metinSolgun,
              size: 22,
            ),
            onTap: () async {
              await widget.veri.takibiDegistir(f.slug);
              if (mounted) setState(() {});
            },
          );
        },
      ),
    );
  }
}
