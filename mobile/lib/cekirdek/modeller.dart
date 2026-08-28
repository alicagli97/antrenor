library;

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

/// Anasayfadaki afiş: içeriği sunucudan yönetilir (banner.json).
class Afis {
  final bool aktif;
  final String tur; // bilgi | sponsor | uyari
  final String baslik;
  final String metin;
  final String butonMetni;
  final String butonHedefi; // federasyonlar | bildirimler | ayarlar | url
  final String url;
  final String renk;

  const Afis({
    required this.aktif,
    required this.tur,
    required this.baslik,
    required this.metin,
    required this.butonMetni,
    required this.butonHedefi,
    required this.url,
    required this.renk,
  });

  static const bos = Afis(
      aktif: false,
      tur: 'bilgi',
      baslik: '',
      metin: '',
      butonMetni: '',
      butonHedefi: '',
      url: '',
      renk: '#E0A33C');

  factory Afis.jsondan(Map<String, dynamic> j) => Afis(
        aktif: j['aktif'] as bool? ?? false,
        tur: j['tur'] as String? ?? 'bilgi',
        baslik: j['baslik'] as String? ?? '',
        metin: j['metin'] as String? ?? '',
        butonMetni: j['buton_metni'] as String? ?? '',
        butonHedefi: j['buton_hedefi'] as String? ?? '',
        url: j['url'] as String? ?? '',
        renk: j['renk'] as String? ?? '#E0A33C',
      );
}

/// Çevrimdışı aramanın tek tip sonucu: duyuru, etkinlik veya belge.
class AramaSonucu {
  final String baslik;
  final String altBilgi;
  final String url;
  final AramaTuru tur;
  final Duyuru? duyuruKaydi;
  final Etkinlik? etkinlikKaydi;

  const AramaSonucu._({
    required this.baslik,
    required this.altBilgi,
    required this.url,
    required this.tur,
    this.duyuruKaydi,
    this.etkinlikKaydi,
  });

  factory AramaSonucu.duyuru(Duyuru d) => AramaSonucu._(
        baslik: d.baslik,
        altBilgi: d.etiketAdi,
        url: d.url,
        tur: AramaTuru.duyuru,
        duyuruKaydi: d,
      );

  factory AramaSonucu.etkinlik(Etkinlik e, String federasyon) => AramaSonucu._(
        baslik: e.ad,
        altBilgi: [federasyon, e.tarihMetni, e.yer]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        url: '',
        tur: AramaTuru.etkinlik,
        etkinlikKaydi: e,
      );

  factory AramaSonucu.belge(Belge b, String federasyon) => AramaSonucu._(
        baslik: b.baslik,
        altBilgi: '$federasyon · ${b.tur.toUpperCase()}',
        url: b.url,
        tur: AramaTuru.belge,
      );
}

enum AramaTuru { duyuru, etkinlik, belge }

/// Bilgi Deposu: 65 federasyonun mevzuat ve oyun kuralları belgeleri tek
/// uçtan (rules.json) gelir. Federasyon federasyon indirmek 49 istek
/// demekti; toplu uç tek istekle iniyor ve çevrimdışı saklanabiliyor.
class MevzuatDeposu {
  final int kutuphaneSayisi;
  final int belgeSayisi;
  final int antrenorBelgesi;

  /// Son günlük kontrolde belgesi değişen federasyonların slug'ları
  final Set<String> degisenler;
  final List<Kutuphane> kutuphaneler;

  const MevzuatDeposu({
    required this.kutuphaneSayisi,
    required this.belgeSayisi,
    required this.antrenorBelgesi,
    required this.degisenler,
    required this.kutuphaneler,
  });

  static const bos = MevzuatDeposu(
      kutuphaneSayisi: 0,
      belgeSayisi: 0,
      antrenorBelgesi: 0,
      degisenler: {},
      kutuphaneler: []);

  factory MevzuatDeposu.jsondan(Map<String, dynamic> j) => MevzuatDeposu(
        kutuphaneSayisi: j['total_libraries'] as int? ?? 0,
        belgeSayisi: j['total_documents'] as int? ?? 0,
        antrenorBelgesi: j['coach_documents'] as int? ?? 0,
        degisenler: ((j['changed_in_last_run'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        kutuphaneler: ((j['libraries'] as List?) ?? const [])
            .map((e) => Kutuphane.jsondan(e as Map<String, dynamic>))
            .toList(),
      );
}

class Kutuphane {
  final String federasyon;
  final String federasyonAdi;
  final String kisaAd;
  final List<Belge> belgeler;
  final DateTime? kontrolTarihi;

  const Kutuphane({
    required this.federasyon,
    required this.federasyonAdi,
    required this.kisaAd,
    required this.belgeler,
    this.kontrolTarihi,
  });

  factory Kutuphane.jsondan(Map<String, dynamic> j) => Kutuphane(
        federasyon: j['federation'] as String? ?? '',
        federasyonAdi: j['federation_name'] as String? ?? '',
        kisaAd: j['federation_short'] as String? ?? '',
        belgeler: ((j['documents'] as List?) ?? const [])
            .map((e) => Belge.jsondan(e as Map<String, dynamic>))
            .toList(),
        kontrolTarihi: DateTime.tryParse(j['checked_at'] as String? ?? ''),
      );
}

/// Belge başlığına göre ayrım: "kural" veya "oyun" geçenler oyun kuralı,
/// geri kalanı talimat/yönetmelik. Kaynaklar bu ayrımı kendileri yapmıyor.
bool oyunKuraliMi(Belge b) {
  final t = b.baslik.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');
  return t.contains('kural') || t.contains('oyun');
}
