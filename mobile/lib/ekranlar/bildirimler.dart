import 'package:flutter/material.dart';

import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import 'duyuru_detay.dart';

/// Bildirimler: takip edilen federasyonların duyuruları — akıştan düşmüş
/// geçmiş kayıtlar dâhil. Her federasyonun kendi arşiv dosyasından okunur.
class BildirimlerEkrani extends StatefulWidget {
  final Veri veri;
  final VoidCallback federasyonlaraGit;
  const BildirimlerEkrani(
      {super.key, required this.veri, required this.federasyonlaraGit});

  @override
  State<BildirimlerEkrani> createState() => _BildirimlerDurumu();
}

class _BildirimlerDurumu extends State<BildirimlerEkrani> {
  List<Duyuru> _liste = const [];
  bool _yukleniyor = true;
  int _takipSayisi = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Takip listesi değiştiyse geçmişi yeniden derle
    if (_takipSayisi != widget.veri.takipEdilen.length) {
      _takipSayisi = widget.veri.takipEdilen.length;
      _yukle();
    }
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final liste = await widget.veri.takipEdilenlerinGecmisi();
    if (!mounted) return;
    setState(() {
      _liste = liste;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final veri = widget.veri;

    if (veri.takipEdilen.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_border,
                  size: 44, color: Renkler.metinSolgun),
              const SizedBox(height: 14),
              const Text('Henüz federasyon takip etmiyorsun',
                  style: Yazi.kartBaslik),
              const SizedBox(height: 8),
              const Text(
                'Federasyonlar sekmesinden yıldıza dokun; buraya o '
                'federasyonların tüm duyuruları düşsün.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Renkler.metinSolgun, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: widget.federasyonlaraGit,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Renkler.metin,
                    side: const BorderSide(color: Renkler.cizgi)),
                child: const Text('Federasyon seç'),
              ),
            ],
          ),
        ),
      );
    }

    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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
              const Icon(Icons.star, size: 16, color: Renkler.kurs),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${veri.takipEdilen.length} federasyon · ${_liste.length} duyuru (geçmiş dâhil)',
                  style: const TextStyle(
                      color: Renkler.metinIkincil, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _liste.isEmpty
              ? const Center(
                  child: Text('Takip edilen federasyonlarda duyuru yok',
                      style: TextStyle(
                          color: Renkler.metinSolgun, fontSize: 13.5)),
                )
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: Renkler.amblemAcik,
                  backgroundColor: Renkler.yuzey,
                  child: ListView.builder(
                    itemCount: _liste.length,
                    itemBuilder: (_, i) => DuyuruKarti(
                      duyuru: _liste[i],
                      takipte: true,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  DuyuruDetay(duyuru: _liste[i]))),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
