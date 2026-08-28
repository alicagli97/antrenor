import 'package:flutter/material.dart';

import '../cekirdek/profil.dart';
import '../cekirdek/tema.dart';
import '../cekirdek/veri.dart';
import '../parcalar/duyuru_karti.dart';
import '../parcalar/erisim.dart';

/// Vize Takibim: uygulamanın kullanıcıya özel tek bölümü.
///
/// Antrenör branşını, kademesini ve vize bitiş tarihini bir kez girer;
/// uygulama geri sayımı yürütür, kendi branşındaki kurs ve vize duyurularını
/// öne çıkarır ve son güne 60/30/7/1 gün kala telefona hatırlatma kurar.
class VizeEkrani extends StatefulWidget {
  final Veri veri;
  const VizeEkrani({super.key, required this.veri});

  @override
  State<VizeEkrani> createState() => _VizeEkraniDurumu();
}

class _VizeEkraniDurumu extends State<VizeEkrani> {
  final _profil = Profil.ornek;

  @override
  void initState() {
    super.initState();
    _profil.addListener(_yenile);
  }

  void _yenile() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _profil.removeListener(_yenile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vize Takibim'),
        actions: [
          if (_profil.kurulu)
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _duzenle,
            ),
        ],
      ),
      body: _profil.kurulu ? _pano() : _kurulum(),
    );
  }

  // --- Kurulum ------------------------------------------------------------

  Widget _kurulum() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Icon(Icons.badge_outlined, size: 44, color: Renkler.kurs),
          const SizedBox(height: 16),
          Text('Vizeni takip edelim', style: Yazi.baslik),
          const SizedBox(height: 10),
          Text(
            'Branşını, kademeni ve vize bitiş tarihini bir kez gir. '
            'Uygulama geri sayımı tutar, kendi branşındaki kurs ve vize '
            'duyurularını öne çıkarır, son güne 60, 30, 7 ve 1 gün kala '
            'telefonuna hatırlatma kurar.',
            style: TextStyle(
                color: Renkler.metinIkincil, fontSize: 14.5, height: 1.55),
          ),
          const SizedBox(height: 10),
          Text('Bu bilgiler yalnızca telefonunda saklanır.', style: Yazi.kucuk),
          const SizedBox(height: 26),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Renkler.kurs,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _duzenle,
            child: const Text('Başla',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      );

  Future<void> _duzenle() async {
    final sonuc = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Renkler.yuzey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _KurulumSayfasi(veri: widget.veri),
    );
    if (sonuc == true && mounted) setState(() {});
  }

  // --- Pano ---------------------------------------------------------------

  Widget _pano() {
    final kalan = _profil.kalanGun!;
    final renk = _durumRengi(_profil.durum);
    final fed = widget.veri.federasyon(_profil.brans!);

    // Kendi bransindaki kurs ve vize duyurulari
    final benimkiler = widget.veri.duyurular
        .where((d) =>
            d.federasyon == _profil.brans &&
            (d.kategori == 'kurs' || d.antrenorIcin))
        .toList()
      ..sort((a, b) => (b.yayinTarihi ?? DateTime(2000))
          .compareTo(a.yayinTarihi ?? DateTime(2000)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(Olcu.kenar, 12, Olcu.kenar, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Olcu.kartYaricap),
            border: Border.all(color: renk.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Text(_durumBasligi(_profil.durum, kalan),
                style: TextStyle(
                    color: renk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Text(
              kalan < 0 ? '${-kalan}' : '$kalan',
              style: TextStyle(
                  color: renk,
                  fontSize: 56,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  fontFamily: Yazi.aile),
            ),
            const SizedBox(height: 4),
            Text(kalan < 0 ? 'gün geçti' : 'gün kaldı',
                style: TextStyle(color: Renkler.metinIkincil, fontSize: 14)),
            const SizedBox(height: 14),
            Text(_tarih(_profil.vizeBitis!),
                style: TextStyle(
                    color: Renkler.metin,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        _Satir(
            etiket: 'Branş', deger: fed?.etiket ?? _profil.brans!),
        _Satir(
            etiket: 'Kademe',
            deger: Profil.kademeler[_profil.kademe] ?? '—'),
        _Satir(
          etiket: 'Hatırlatmalar',
          deger: '${Profil.uyariGunleri.join(", ")} gün kala',
        ),
        const SizedBox(height: 22),
        Row(children: [
          Text('Branşındaki kurs ve vize duyuruları', style: Yazi.baslik),
        ]),
        const SizedBox(height: 4),
        Text('${benimkiler.length} kayıt', style: Yazi.kucuk),
        const SizedBox(height: 10),
        if (benimkiler.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'Bu federasyonda şu an kurs veya vize duyurusu yok. '
              'Yeni duyuru çıkınca bildirim alırsın.',
              style: TextStyle(
                  color: Renkler.metinIkincil, fontSize: 13.5, height: 1.5),
            ),
          )
        else
          for (final d in benimkiler.take(15))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DuyuruKarti(
                duyuru: d,
                takipte: widget.veri.takipEdilen.contains(d.federasyon),
                onTap: () => duyuruyuAc(context, d),
              ),
            ),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () async {
            await _profil.sil();
            if (mounted) setState(() {});
          },
          child: Text('Vize takibini kapat',
              style: TextStyle(color: Renkler.metinSolgun, fontSize: 13)),
        ),
      ],
    );
  }

  static Color _durumRengi(VizeDurumu d) => switch (d) {
        VizeDurumu.gecti => Renkler.musabaka,
        VizeDurumu.acil => Renkler.musabaka,
        VizeDurumu.yaklasiyor => Renkler.kurs,
        _ => Renkler.takvim,
      };

  static String _durumBasligi(VizeDurumu d, int kalan) => switch (d) {
        VizeDurumu.gecti => 'VİZE SÜRESİ DOLDU',
        VizeDurumu.acil => 'SON DÖNEM',
        VizeDurumu.yaklasiyor => 'YAKLAŞIYOR',
        _ => 'VİZE GEÇERLİ',
      };

  static String _tarih(DateTime t) {
    const aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${t.day} ${aylar[t.month - 1]} ${t.year}';
  }
}

class _Satir extends StatelessWidget {
  final String etiket;
  final String deger;
  const _Satir({required this.etiket, required this.deger});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 116, child: Text(etiket, style: Yazi.kucuk)),
          Expanded(
            child: Text(deger,
                style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
          ),
        ]),
      );
}

/// Branş, kademe ve tarih seçimi
class _KurulumSayfasi extends StatefulWidget {
  final Veri veri;
  const _KurulumSayfasi({required this.veri});

  @override
  State<_KurulumSayfasi> createState() => _KurulumSayfasiDurumu();
}

class _KurulumSayfasiDurumu extends State<_KurulumSayfasi> {
  final _profil = Profil.ornek;
  late String? _brans = _profil.brans;
  late int _kademe = _profil.kademe ?? 1;
  late DateTime? _tarih = _profil.vizeBitis;

  bool get _tamam => _brans != null && _tarih != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vize bilgilerin', style: Yazi.baslik),
          const SizedBox(height: 18),
          Text('Branş', style: Yazi.kucuk),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _brans,
            isExpanded: true,
            dropdownColor: Renkler.yuzeyYuksek,
            decoration: _kutu(),
            hint: Text('Federasyon seç',
                style: TextStyle(color: Renkler.metinSolgun, fontSize: 14)),
            items: [
              for (final f in widget.veri.federasyonlar)
                DropdownMenuItem(
                  value: f.slug,
                  child: Text(f.etiket,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
                ),
            ],
            onChanged: (v) => setState(() => _brans = v),
          ),
          const SizedBox(height: 16),
          Text('Kademe', style: Yazi.kucuk),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _kademe,
            isExpanded: true,
            dropdownColor: Renkler.yuzeyYuksek,
            decoration: _kutu(),
            items: [
              for (final g in Profil.kademeler.entries)
                DropdownMenuItem(
                  value: g.key,
                  child: Text(g.value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Renkler.metin, fontSize: 14.5)),
                ),
            ],
            onChanged: (v) => setState(() => _kademe = v ?? 1),
          ),
          const SizedBox(height: 16),
          Text('Vize bitiş tarihi', style: Yazi.kucuk),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: _tarihSec,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Renkler.cizgi),
              ),
              child: Row(children: [
                Icon(Icons.event, size: 18, color: Renkler.metinSolgun),
                const SizedBox(width: 10),
                Text(
                  _tarih == null
                      ? 'Tarih seç'
                      : _VizeEkraniDurumu._tarih(_tarih!),
                  style: TextStyle(
                      color: _tarih == null
                          ? Renkler.metinSolgun
                          : Renkler.metin,
                      fontSize: 14.5),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _tamam ? Renkler.kurs : Renkler.yuzeyYuksek,
                foregroundColor: _tamam ? Colors.black : Renkler.metinSolgun,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _tamam ? _kaydet : null,
              child: const Text('Kaydet ve hatırlatmaları kur',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _kutu() => InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Renkler.cizgi),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Renkler.cizgi),
        ),
      );

  Future<void> _tarihSec() async {
    final bugun = DateTime.now();
    final secim = await showDatePicker(
      context: context,
      initialDate: _tarih ?? DateTime(bugun.year + 1, bugun.month, bugun.day),
      firstDate: DateTime(bugun.year - 3),
      lastDate: DateTime(bugun.year + 10),
      helpText: 'Vize bitiş tarihi',
    );
    if (secim != null) setState(() => _tarih = secim);
  }

  Future<void> _kaydet() async {
    await _profil.kaydet(
        brans: _brans!, kademe: _kademe, vizeBitis: _tarih!);
    if (mounted) Navigator.of(context).pop(true);
  }
}
