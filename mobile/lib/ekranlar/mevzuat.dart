import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';

/// Mevzuat: federasyonların talimatları, yönetmelikleri ve oyun kuralları.
/// Antrenörü ilgilendiren belgeler öne alınır.
class MevzuatEkrani extends StatefulWidget {
  final Veri veri;
  const MevzuatEkrani({super.key, required this.veri});

  @override
  State<MevzuatEkrani> createState() => _MevzuatDurumu();
}

class _MevzuatDurumu extends State<MevzuatEkrani> {
  bool _yukleniyor = true;
  bool _sadeceAntrenor = true;
  String _arama = '';

  @override
  void initState() {
    super.initState();
    widget.veri.mevzuatGetir().whenComplete(
        () => mounted ? setState(() => _yukleniyor = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final veri = widget.veri;

    final kutuphaneler = veri.mevzuat
        .where((k) => _belgeler(k).isNotEmpty)
        .toList()
      ..sort((a, b) =>
          veri.etiketAdi(a.federasyon).compareTo(veri.etiketAdi(b.federasyon)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: TextField(
            style: const TextStyle(color: Renkler.metin, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Talimat ara — ör. antrenör eğitim',
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Renkler.amblemOrta),
              ),
            ),
            onChanged: (d) => setState(() => _arama = d),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: FilterChip(
              label: const Text('Sadece antrenör belgeleri'),
              selected: _sadeceAntrenor,
              onSelected: (d) => setState(() => _sadeceAntrenor = d),
              backgroundColor: Renkler.yuzey,
              selectedColor: Renkler.kurs.withValues(alpha: 0.16),
              checkmarkColor: Renkler.kurs,
              labelStyle: TextStyle(
                  color:
                      _sadeceAntrenor ? Renkler.kurs : Renkler.metinIkincil,
                  fontSize: 12.5),
              side: BorderSide(
                  color: _sadeceAntrenor
                      ? Renkler.kurs.withValues(alpha: 0.4)
                      : Renkler.cizgi),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            itemCount: kutuphaneler.length,
            itemBuilder: (_, i) {
              final k = kutuphaneler[i];
              final belgeler = _belgeler(k);
              return Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(veri.etiketAdi(k.federasyon),
                      style: const TextStyle(
                          color: Renkler.metin,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('${belgeler.length} belge',
                      style: const TextStyle(
                          color: Renkler.metinSolgun, fontSize: 12.5)),
                  iconColor: Renkler.metinSolgun,
                  collapsedIconColor: Renkler.metinSolgun,
                  children:
                      belgeler.map((b) => _BelgeSatiri(belge: b)).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Belge> _belgeler(MevzuatKutuphanesi k) {
    final sorgu = _arama.toLowerCase();
    return k.belgeler.where((b) {
      if (_sadeceAntrenor && !b.antrenorIcin) return false;
      if (sorgu.isNotEmpty && !b.baslik.toLowerCase().contains(sorgu)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _BelgeSatiri extends StatelessWidget {
  final Belge belge;
  const _BelgeSatiri({required this.belge});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 22, right: 14),
        leading: Icon(
          belge.tur == 'pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.description_outlined,
          size: 18,
          color: belge.antrenorIcin ? Renkler.kurs : Renkler.metinSolgun,
        ),
        title: Text(belge.baslik,
            style: const TextStyle(
                color: Renkler.metinIkincil, fontSize: 13.5, height: 1.3)),
        onTap: () => launchUrl(Uri.parse(belge.url),
            mode: LaunchMode.externalApplication),
      );
}
