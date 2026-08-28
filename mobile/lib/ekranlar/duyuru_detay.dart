import 'package:flutter/material.dart';

import '../cekirdek/baglanti.dart';
import '../cekirdek/depo.dart';
import '../cekirdek/hatirlatici.dart';
import '../cekirdek/modeller.dart';
import '../cekirdek/tema.dart';

/// Duyuru detayı. Özet gösterilir, tam metin için kaynağa yönlendirilir:
/// içeriğin resmî ve bağlayıcı hâli federasyonun kendi sitesindedir.
///
/// Kaydetme ve hatırlatma tamamen cihazda çalışır: kaydedilen duyuru
/// internetsiz de okunur, hatırlatma telefonun kendi zamanlayıcısına yazılır.
class DuyuruDetay extends StatefulWidget {
  final Duyuru duyuru;
  const DuyuruDetay({super.key, required this.duyuru});

  @override
  State<DuyuruDetay> createState() => _DuyuruDetayDurumu();
}

class _DuyuruDetayDurumu extends State<DuyuruDetay> {
  bool _kayitli = false;
  DateTime? _hatirlatma;

  String get _anahtar => 'duyuru:${widget.duyuru.id}';

  @override
  void initState() {
    super.initState();
    _durumuOku();
  }

  Future<void> _durumuOku() async {
    final kimlikler = await Depo.kayitliKimlikler();
    final kurulu = await Hatirlatici.liste();
    if (!mounted) return;
    setState(() {
      _kayitli = kimlikler.contains(widget.duyuru.id);
      for (final h in kurulu) {
        if (h.anahtar == _anahtar) _hatirlatma = h.ne;
      }
    });
  }

  Future<void> _kaydiDegistir() async {
    final sonuc = await Depo.kaydiDegistir(widget.duyuru);
    if (!mounted) return;
    setState(() => _kayitli = sonuc);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sonuc
          ? 'Kaydedildi — çevrimdışı da okuyabilirsiniz'
          : 'Kayıtlardan çıkarıldı'),
    ));
  }

  Future<void> _hatirlatmaKur() async {
    if (_hatirlatma != null) {
      await Hatirlatici.iptal(_anahtar);
      if (!mounted) return;
      setState(() => _hatirlatma = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatma kaldırıldı')),
      );
      return;
    }

    final bugun = DateTime.now();
    final gun = await showDatePicker(
      context: context,
      initialDate: bugun.add(const Duration(days: 1)),
      firstDate: bugun,
      lastDate: bugun.add(const Duration(days: 365)),
      helpText: 'Ne zaman hatırlatalım?',
    );
    if (gun == null || !mounted) return;

    final saat = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Saat seçin',
    );
    if (saat == null || !mounted) return;

    final ne = DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute);

    await Hatirlatici.izinIste();
    final oldu = await Hatirlatici.kur(
      anahtar: _anahtar,
      baslik: widget.duyuru.etiketAdi,
      metin: widget.duyuru.baslik,
      ne: ne,
    );
    if (!mounted) return;

    setState(() => _hatirlatma = oldu ? ne : null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(oldu
          ? 'Hatırlatma kuruldu: ${_tarihSaat(ne)}'
          : 'Hatırlatma kurulamadı. Bildirim izni kapalı olabilir.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final duyuru = widget.duyuru;
    final renk = Renkler.kategoriRengi(duyuru.kategori);

    return Scaffold(
      appBar: AppBar(
        title: Text(duyuru.etiketAdi, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: _kayitli ? 'Kayıtlardan çıkar' : 'Kaydet',
            icon: Icon(_kayitli ? Icons.bookmark : Icons.bookmark_border,
                color: _kayitli ? renk : Renkler.metinIkincil),
            onPressed: _kaydiDegistir,
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
            Text(_tarih(duyuru.yayinTarihi), style: Yazi.kucuk),
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
          const SizedBox(height: 24),
          _Eylem(
            simge: _hatirlatma == null
                ? Icons.notifications_none
                : Icons.notifications_active,
            metin: _hatirlatma == null
                ? 'Hatırlatıcı kur'
                : 'Hatırlatma: ${_tarihSaat(_hatirlatma!)}',
            altMetin: _hatirlatma == null
                ? 'Son başvuru veya kurs tarihini kaçırmayın'
                : 'Kaldırmak için dokunun',
            renk: _hatirlatma == null ? Renkler.metin : renk,
            onPressed: _hatirlatmaKur,
          ),
          const SizedBox(height: 10),
          _Eylem(
            simge: _kayitli ? Icons.bookmark : Icons.bookmark_border,
            metin: _kayitli ? 'Kaydedildi' : 'Kaydet',
            altMetin: 'Kayıtlı duyurular internetsiz de açılır',
            renk: _kayitli ? renk : Renkler.metin,
            onPressed: _kaydiDegistir,
          ),
          const SizedBox(height: 10),
          _Eylem(
            simge: Icons.open_in_new,
            metin: 'Kaynakta aç',
            altMetin: duyuru.federasyonAdi,
            renk: Renkler.metin,
            onPressed: () => Baglanti.ac(context, duyuru.url),
          ),
          const SizedBox(height: 16),
          Text(
            'Duyurunun resmî ve bağlayıcı hâli ${duyuru.federasyonAdi} sitesindedir.',
            style: TextStyle(
                color: Renkler.metinSolgun, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _tarih(DateTime? t) => t == null
      ? ''
      : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';

  static String _tarihSaat(DateTime t) =>
      '${_tarih(t)} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Detay ekranındaki eylem satırı: simge, başlık, açıklama.
class _Eylem extends StatelessWidget {
  final IconData simge;
  final String metin;
  final String altMetin;
  final Color renk;
  final VoidCallback onPressed;

  const _Eylem({
    required this.simge,
    required this.metin,
    required this.altMetin,
    required this.renk,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Renkler.yuzeyYuksek,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Renkler.cizgi),
          ),
          child: Row(children: [
            Icon(simge, size: 20, color: renk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metin,
                      style: TextStyle(
                          color: renk,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(altMetin, style: Yazi.kucuk),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Renkler.metinSolgun),
          ]),
        ),
      ),
    );
  }
}
