import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'federasyon_detay.dart';

/// Federasyonlar: 65 kurum kart listesinde. Yıldız takibe alır; karta
/// dokununca federasyonun duyuru, takvim, mevzuat ve kural sayfası açılır.
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
          padding: const EdgeInsets.fromLTRB(Olcu.kenar, 4, Olcu.kenar, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Renkler.yuzey,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Renkler.cizgi),
            ),
            child: TextField(
              style: Yazi.govde.copyWith(color: Renkler.metin, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Branş ara — yüzme, hentbol, atletizm…',
                hintStyle: Yazi.govde.copyWith(color: Renkler.metinSolgun),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: Renkler.metinSolgun),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (d) => setState(() => _arama = d),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Olcu.kenar),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _sadeceTakip = !_sadeceTakip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: _sadeceTakip
                        ? Renkler.kurs.withValues(alpha: 0.16)
                        : Renkler.yuzey,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: _sadeceTakip
                            ? Renkler.kurs.withValues(alpha: 0.45)
                            : Renkler.cizgi),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _sadeceTakip
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 15,
                          color: _sadeceTakip
                              ? Renkler.kurs
                              : Renkler.metinSolgun),
                      const SizedBox(width: 6),
                      Text('Takip ettiklerim  ${veri.takipEdilen.length}',
                          style: Yazi.govde.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _sadeceTakip
                                  ? Renkler.kurs
                                  : Renkler.metinIkincil)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text('${liste.length} KURUM', style: Yazi.etiket),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: liste.isEmpty
              ? const Center(child: Text('Sonuç yok', style: Yazi.govde))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: liste.length,
                  itemBuilder: (_, i) {
                    final f = liste[i];
                    final takipte = veri.takipEdilen.contains(f.slug);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Olcu.kenar, 0, Olcu.kenar, 10),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => FederasyonDetay(
                                    veri: veri, federasyon: f))),
                        child: Container(
                          decoration: kartYuzeyi(
                              vurgu: takipte
                                  ? Renkler.federasyonRengi(f.slug)
                                  : null),
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Row(
                            children: [
                              FederasyonRozeti(slug: f.slug, ad: f.etiket),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(f.etiket,
                                        style: Yazi.kartBaslik
                                            .copyWith(fontSize: 15.5)),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (f.olimpik) 'Olimpik',
                                        if (f.para) 'Paralimpik',
                                        '${f.duyuruSayisi} duyuru',
                                      ].join('  ·  '),
                                      style: Yazi.kucuk,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    takipte
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: takipte
                                        ? Renkler.kurs
                                        : Renkler.metinSolgun,
                                    size: 23),
                                tooltip:
                                    takipte ? 'Takibi bırak' : 'Takip et',
                                onPressed: () async {
                                  await veri.takibiDegistir(f.slug);
                                  if (context.mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
