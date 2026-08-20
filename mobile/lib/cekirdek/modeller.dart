/// Sunucudaki JSON uçlarının karşılıkları.
/// Kaynak: https://alicagli97.github.io/antrenor/api/v1/

class Duyuru {
  final String id;
  final String federasyon; // slug
  final String federasyonAdi;
  final String etiketAdi; // kısa, benzersiz görünen ad (Basketbol, Boks…)
  final String baslik;
  final String url;
  final String ozet;
  final String? gorsel;
  final String kategori;
  final List<String> etiketler;
  final DateTime? yayinTarihi;

  const Duyuru({
    required this.id,
    required this.federasyon,
    required this.federasyonAdi,
    required this.etiketAdi,
    required this.baslik,
    required this.url,
    required this.ozet,
    required this.kategori,
    required this.etiketler,
    this.gorsel,
    this.yayinTarihi,
  });

  factory Duyuru.jsondan(Map<String, dynamic> j, {String? etiket}) => Duyuru(
        id: j['id'] as String? ?? '',
        federasyon: j['federation'] as String? ?? '',
        federasyonAdi: j['federation_name'] as String? ?? '',
        etiketAdi: etiket ?? j['federation_short'] as String? ?? '',
        baslik: j['title'] as String? ?? '',
        url: j['url'] as String? ?? '',
        ozet: j['summary'] as String? ?? '',
        gorsel: j['image'] as String?,
        kategori: j['category'] as String? ?? 'duyuru',
        etiketler:
            (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        yayinTarihi: DateTime.tryParse(j['published_at'] as String? ?? ''),
      );

  bool get antrenorIcin => etiketler.contains('antrenor');
}

class Federasyon {
  final String slug;
  final String ad;
  final String kisaAd; // resmî kısaltma (benzersiz değil)
  final String etiket; // arayüzde kullanılan benzersiz ad
  final String site;
  final List<String> branslar;
  final bool olimpik;
  final bool para;
  final int duyuruSayisi;
  final String konu; // bildirim konusu (fed_<slug>)

  const Federasyon({
    required this.slug,
    required this.ad,
    required this.kisaAd,
    required this.etiket,
    required this.site,
    required this.branslar,
    required this.olimpik,
    required this.para,
    required this.duyuruSayisi,
    required this.konu,
  });

  factory Federasyon.jsondan(Map<String, dynamic> j) => Federasyon(
        slug: j['slug'] as String? ?? '',
        ad: j['name'] as String? ?? '',
        kisaAd: j['short'] as String? ?? '',
        etiket: (j['label'] as String?) ?? _etiketUret(j['name'] as String? ?? ''),
        site: j['site'] as String? ?? '',
        branslar:
            (j['branches'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        olimpik: j['olympic'] as bool? ?? false,
        para: j['para'] as bool? ?? false,
        duyuruSayisi: j['announcement_count'] as int? ?? 0,
        konu: j['topic'] as String? ?? '',
      );

  /// Sunucu henüz `label` göndermiyorsa addan üret.
  static String _etiketUret(String ad) => ad
      .replaceAll('Türkiye ', '')
      .replaceAll(' Spor Federasyonu', '')
      .replaceAll(' Federasyonu', '')
      .trim();
}

class Etkinlik {
  final String ad;
  final DateTime? tarih;
  final String tarihMetni;
  final String yer;
  final String brans;

  const Etkinlik({
    required this.ad,
    this.tarih,
    this.tarihMetni = '',
    this.yer = '',
    this.brans = '',
  });

  factory Etkinlik.jsondan(Map<String, dynamic> j) => Etkinlik(
        ad: j['ad'] as String? ?? '',
        tarih: DateTime.tryParse(j['tarih'] as String? ?? ''),
        tarihMetni: j['tarih_metni'] as String? ?? '',
        yer: j['yer'] as String? ?? '',
        brans: j['brans'] as String? ?? '',
      );
}

class Takvim {
  final String federasyon;
  final String federasyonAdi;
  final String url;
  final String tur; // html | pdf | excel | word
  final int etkinlikSayisi;
  final List<Etkinlik> etkinlikler;

  const Takvim({
    required this.federasyon,
    required this.federasyonAdi,
    required this.url,
    required this.tur,
    required this.etkinlikSayisi,
    required this.etkinlikler,
  });

  factory Takvim.jsondan(Map<String, dynamic> j) => Takvim(
        federasyon: j['federation'] as String? ?? '',
        federasyonAdi: j['federation_name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        tur: j['type'] as String? ?? 'html',
        etkinlikSayisi: j['event_count'] as int? ?? 0,
        etkinlikler: (j['events'] as List?)
                ?.map((e) => Etkinlik.jsondan(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class Belge {
  final String baslik;
  final String url;
  final String tur;
  final bool antrenorIcin;

  const Belge({
    required this.baslik,
    required this.url,
    required this.tur,
    required this.antrenorIcin,
  });

  factory Belge.jsondan(Map<String, dynamic> j) => Belge(
        baslik: j['baslik'] as String? ?? '',
        url: j['url'] as String? ?? '',
        tur: j['tur'] as String? ?? 'pdf',
        antrenorIcin: j['onemli'] as bool? ?? false,
      );
}

class MevzuatKutuphanesi {
  final String federasyon;
  final String federasyonAdi;
  final int belgeSayisi;
  final int antrenorBelgesi;
  final List<Belge> belgeler;

  const MevzuatKutuphanesi({
    required this.federasyon,
    required this.federasyonAdi,
    required this.belgeSayisi,
    required this.antrenorBelgesi,
    required this.belgeler,
  });

  factory MevzuatKutuphanesi.jsondan(Map<String, dynamic> j) =>
      MevzuatKutuphanesi(
        federasyon: j['federation'] as String? ?? '',
        federasyonAdi: j['federation_name'] as String? ?? '',
        belgeSayisi: j['document_count'] as int? ?? 0,
        antrenorBelgesi: j['coach_document_count'] as int? ?? 0,
        belgeler: (j['documents'] as List?)
                ?.map((e) => Belge.jsondan(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
