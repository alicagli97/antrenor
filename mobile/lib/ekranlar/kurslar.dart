import 'package:flutter/material.dart';

import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'duyuru_detay.dart';

/// Kurslar: antrenörü doğrudan ilgilendiren duyurular (kademe kursu, vize,
/// terfi, seminer). Uygulamanın asıl değeri burada.
class KurslarEkrani extends StatelessWidget {
  final Veri veri;
  const KurslarEkrani({super.key, required this.veri});

  @override
  Widget build(BuildContext context) {
    final liste = veri.kurslar;
    if (liste.isEmpty) {
      return const Center(
        child: Text('Şu an kurs duyurusu yok',
            style: TextStyle(color: Renkler.metinSolgun)),
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Renkler.cizgi)),
          ),
          child: Row(
            children: [
              const Icon(Icons.school_outlined, size: 17, color: Renkler.kurs),
              const SizedBox(width: 8),
              Text('${liste.length} kurs, vize ve seminer duyurusu',
                  style: const TextStyle(
                      color: Renkler.metinIkincil, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: liste.length,
            itemBuilder: (_, i) => DuyuruKarti(
              duyuru: liste[i],
              takipte: veri.takipEdilen.contains(liste[i].federasyon),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DuyuruDetay(duyuru: liste[i]))),
            ),
          ),
        ),
      ],
    );
  }
}
