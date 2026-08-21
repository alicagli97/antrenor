import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Görsel dil. İki palet var: koyu ve açık. Ayarlar'daki anahtar
/// `Renkler.paletiDegistir` ile aktif paleti değiştirir, uygulama kökü
/// yeniden çizilir.
///
/// Not: renkler sabit (const) değil, aktif paletten okunan getter'lar.
/// Bu yüzden widget ağacında `const` kullanılamaz; karşılığında tek bir
/// anahtarla tüm uygulama tema değiştirebiliyor.
class Palet {
  final Color zemin;
  final Color yuzey;
  final Color yuzeyYuksek;
  final Color cizgi;
  final Color cizgiParlak;
  final Color metin;
  final Color metinIkincil;
  final Color metinSolgun;
  final Color kurs;
  final Color musabaka;
  final Color mevzuat;
  final Color takvim;
  final Color duyuru;
  final Brightness parlaklik;

  const Palet({
    required this.zemin,
    required this.yuzey,
    required this.yuzeyYuksek,
    required this.cizgi,
    required this.cizgiParlak,
    required this.metin,
    required this.metinIkincil,
    required this.metinSolgun,
    required this.kurs,
    required this.musabaka,
    required this.mevzuat,
    required this.takvim,
    required this.duyuru,
    required this.parlaklik,
  });

  /// Koyu palet — gece mavisine çalan, mürekkep siyahı kadar sert değil
  static const koyu = Palet(
    zemin: Color(0xFF13181F),
    yuzey: Color(0xFF1B222C),
    yuzeyYuksek: Color(0xFF232C38),
    cizgi: Color(0xFF2C3644),
    cizgiParlak: Color(0xFF3A4757),
    metin: Color(0xFFF2F5F8),
    metinIkincil: Color(0xFFAEBAC7),
    metinSolgun: Color(0xFF7A8794),
    kurs: Color(0xFFF5B942),
    musabaka: Color(0xFF5AA6F5),
    mevzuat: Color(0xFFB197F7),
    takvim: Color(0xFF4FD3A5),
    duyuru: Color(0xFF9AA6B3),
    parlaklik: Brightness.dark,
  );

  /// Açık palet — kâğıt beyazı değil, hafif soğuk gri
  static const acik = Palet(
    zemin: Color(0xFFF4F6F9),
    yuzey: Color(0xFFFFFFFF),
    yuzeyYuksek: Color(0xFFFFFFFF),
    cizgi: Color(0xFFE1E6ED),
    cizgiParlak: Color(0xFFCBD3DE),
    metin: Color(0xFF121821),
    metinIkincil: Color(0xFF4A5765),
    metinSolgun: Color(0xFF7C8895),
    kurs: Color(0xFFC97A0B),
    musabaka: Color(0xFF1E6FC4),
    mevzuat: Color(0xFF6A4FCB),
    takvim: Color(0xFF17845F),
    duyuru: Color(0xFF64707D),
    parlaklik: Brightness.light,
  );
}

class Renkler {
  static Palet _aktif = Palet.koyu;

  static void paletiDegistir(bool koyu) =>
      _aktif = koyu ? Palet.koyu : Palet.acik;

  static bool get koyuMu => _aktif.parlaklik == Brightness.dark;

  static Color get zemin => _aktif.zemin;
  static Color get yuzey => _aktif.yuzey;
  static Color get yuzeyYuksek => _aktif.yuzeyYuksek;
  static Color get cizgi => _aktif.cizgi;
  static Color get cizgiParlak => _aktif.cizgiParlak;
  static Color get metin => _aktif.metin;
  static Color get metinIkincil => _aktif.metinIkincil;
  static Color get metinSolgun => _aktif.metinSolgun;

  static Color get kurs => _aktif.kurs;
  static Color get musabaka => _aktif.musabaka;
  static Color get mevzuat => _aktif.mevzuat;
  static Color get takvim => _aktif.takvim;
  static Color get duyuru => _aktif.duyuru;

  static const amblemAcik = Color(0xFFC6C6C6);
  static const amblemOrta = Color(0xFF7D7D7D);

  static Color kategoriRengi(String kategori) => switch (kategori) {
        'kurs' => kurs,
        'musabaka' => musabaka,
        'mevzuat' => mevzuat,
        'takvim' => takvim,
        'haber' => duyuru,
        _ => duyuru,
      };

  static String kategoriAdi(String kategori) => switch (kategori) {
        'kurs' => 'Kurs',
        'musabaka' => 'Müsabaka',
        'mevzuat' => 'Mevzuat',
        'takvim' => 'Takvim',
        'haber' => 'Haber',
        _ => 'Duyuru',
      };

  /// Federasyon rozetleri: aynı federasyon her yerde aynı renkte görünsün
  /// diye renk slug'dan üretiliyor. Açık temada tonlar koyulaştırılır.
  static const _paletKoyu = [
    Color(0xFF5AA6F5), Color(0xFF4FD3A5), Color(0xFFF5B942), Color(0xFFB197F7),
    Color(0xFFF57B7B), Color(0xFF52C9DE), Color(0xFFDC97EC), Color(0xFF8FC756),
  ];
  static const _paletAcik = [
    Color(0xFF1E6FC4), Color(0xFF17845F), Color(0xFFB8760A), Color(0xFF6A4FCB),
    Color(0xFFC64545), Color(0xFF1A8798), Color(0xFF9B4BB0), Color(0xFF5B8B2A),
  ];

  static Color federasyonRengi(String slug) {
    var toplam = 0;
    for (final kod in slug.codeUnits) {
      toplam = (toplam * 31 + kod) & 0x7FFFFFFF;
    }
    final palet = koyuMu ? _paletKoyu : _paletAcik;
    return palet[toplam % palet.length];
  }
}

class Olcu {
  static const kartYaricap = 18.0;
  static const rozetYaricap = 8.0;
  static const kenar = 16.0;
  static const kartArasi = 12.0;
}

/// Tipografi — Barlow: sportif, hafif dar, logo yazısının havasına yakın
class Yazi {
  static const aile = 'Barlow';

  static TextStyle get dev => TextStyle(
      fontFamily: aile,
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: Renkler.metin);

  static TextStyle get baslik => TextStyle(
      fontFamily: aile,
      fontSize: 20,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Renkler.metin);

  static TextStyle get kartBaslik => TextStyle(
      fontFamily: aile,
      fontSize: 16.5,
      height: 1.28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: Renkler.metin);

  static TextStyle get govde => TextStyle(
      fontFamily: aile,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: Renkler.metinIkincil);

  static TextStyle get kucuk => TextStyle(
      fontFamily: aile,
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: Renkler.metinSolgun);

  static TextStyle get etiket => TextStyle(
      fontFamily: aile,
      fontSize: 11,
      height: 1.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: Renkler.metinSolgun);

  static TextStyle get rakam => TextStyle(
      fontFamily: aile,
      fontSize: 22,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Renkler.metin);
}

/// Kart yüzeyi: koyu temada hafif degrade, açık temada düz beyaz + gölge
BoxDecoration kartYuzeyi({Color? vurgu, bool basili = false}) {
  final kenarRengi = vurgu?.withValues(alpha: Renkler.koyuMu ? 0.26 : 0.34) ??
      Renkler.cizgi;
  if (Renkler.koyuMu) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          basili ? Renkler.yuzeyYuksek : Renkler.yuzey,
          Renkler.zemin,
        ],
      ),
      borderRadius: BorderRadius.circular(Olcu.kartYaricap),
      border: Border.all(color: kenarRengi),
    );
  }
  return BoxDecoration(
    color: basili ? const Color(0xFFF0F3F7) : Renkler.yuzey,
    borderRadius: BorderRadius.circular(Olcu.kartYaricap),
    border: Border.all(color: kenarRengi),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1A2434).withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

ThemeData antrenorTemasi() {
  final koyu = Renkler.koyuMu;
  final taban = ColorScheme(
    brightness: koyu ? Brightness.dark : Brightness.light,
    surface: Renkler.zemin,
    onSurface: Renkler.metin,
    primary: Renkler.metin,
    onPrimary: Renkler.zemin,
    secondary: Renkler.kurs,
    onSecondary: Renkler.zemin,
    error: const Color(0xFFE05656),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: taban,
    scaffoldBackgroundColor: Renkler.zemin,
    fontFamily: Yazi.aile,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Renkler.zemin,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: koyu ? Brightness.light : Brightness.dark,
        statusBarBrightness: koyu ? Brightness.dark : Brightness.light,
      ),
      titleTextStyle: Yazi.baslik,
      iconTheme: IconThemeData(color: Renkler.metinIkincil),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Renkler.yuzey,
      surfaceTintColor: Colors.transparent,
      indicatorColor: koyu ? Renkler.cizgiParlak : Renkler.zemin,
      indicatorShape: const StadiumBorder(),
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (durum) => TextStyle(
          fontFamily: Yazi.aile,
          fontSize: 11.5,
          letterSpacing: 0.1,
          fontWeight: durum.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: durum.contains(WidgetState.selected)
              ? Renkler.metin
              : Renkler.metinSolgun,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (durum) => IconThemeData(
          size: 23,
          color: durum.contains(WidgetState.selected)
              ? Renkler.metin
              : Renkler.metinSolgun,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: Renkler.cizgi, thickness: 1),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: Renkler.metinIkincil),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Renkler.yuzeyYuksek,
      contentTextStyle: TextStyle(fontFamily: Yazi.aile, color: Renkler.metin),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
