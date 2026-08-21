import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Görsel dil. Logodan türetildi: mürekkep siyahı zemin, metalik gri yüzeyler,
/// kategori başına tek bir imza rengi. Amaç sıralı bir liste değil, taranabilir
/// bir akış: her kart kendi başına bir nesne gibi dursun.
class Renkler {
  // Zemin katmanları — hepsi hafif mavi kırık siyah, düz gri değil
  static const zemin = Color(0xFF07090C);
  static const yuzey = Color(0xFF0E1218);
  static const yuzeyYuksek = Color(0xFF151B23);
  static const cizgi = Color(0xFF1E2630);
  static const cizgiParlak = Color(0xFF2A3542);

  // Metin
  static const metin = Color(0xFFF4F6F8);
  static const metinIkincil = Color(0xFF9BA7B4);
  static const metinSolgun = Color(0xFF5F6B78);

  // Amblem tonları — vurgu gradyanlarında kullanılır
  static const amblemAcik = Color(0xFFC6C6C6);
  static const amblemOrta = Color(0xFF7D7D7D);

  /// Kategori imza renkleri
  static const kurs = Color(0xFFF2A93B);
  static const musabaka = Color(0xFF4C9AF0);
  static const mevzuat = Color(0xFFA98BF5);
  static const takvim = Color(0xFF3FC79A);
  static const duyuru = Color(0xFF8C98A6);

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

  /// Federasyon rozetleri için sabit renk: aynı federasyon her yerde aynı
  /// renkte görünsün diye slug'dan üretiliyor.
  static const _paletKok = [
    Color(0xFF4C9AF0), Color(0xFF3FC79A), Color(0xFFF2A93B), Color(0xFFA98BF5),
    Color(0xFFEF6C6C), Color(0xFF48BFD4), Color(0xFFD08BE0), Color(0xFF7FB84A),
  ];

  static Color federasyonRengi(String slug) {
    var toplam = 0;
    for (final kod in slug.codeUnits) {
      toplam = (toplam * 31 + kod) & 0x7FFFFFFF;
    }
    return _paletKok[toplam % _paletKok.length];
  }
}

/// Ölçü sistemi: her yerde aynı ritim
class Olcu {
  static const kartYaricap = 18.0;
  static const rozetYaricap = 8.0;
  static const kenar = 16.0;
  static const kartArasi = 12.0;
}

/// Tipografi — Barlow: sportif, hafif dar, logo yazısının havasına yakın
class Yazi {
  static const aile = 'Barlow';

  static const dev = TextStyle(
      fontFamily: aile,
      fontSize: 30,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: Renkler.metin);

  static const baslik = TextStyle(
      fontFamily: aile,
      fontSize: 20,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Renkler.metin);

  static const kartBaslik = TextStyle(
      fontFamily: aile,
      fontSize: 16.5,
      height: 1.28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      color: Renkler.metin);

  static const govde = TextStyle(
      fontFamily: aile,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: Renkler.metinIkincil);

  static const kucuk = TextStyle(
      fontFamily: aile,
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: Renkler.metinSolgun);

  /// Büyük harf mikro etiket — kategori, bölüm başlığı
  static const etiket = TextStyle(
      fontFamily: aile,
      fontSize: 11,
      height: 1.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: Renkler.metinSolgun);

  static const rakam = TextStyle(
      fontFamily: aile,
      fontSize: 22,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Renkler.metin);
}

/// Kartlarda kullanılan yumuşak yüzey degradesi — düz renk yerine derinlik
BoxDecoration kartYuzeyi({Color? vurgu, bool basili = false}) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          basili ? Renkler.yuzeyYuksek : Renkler.yuzey,
          Renkler.zemin,
        ],
      ),
      borderRadius: BorderRadius.circular(Olcu.kartYaricap),
      border: Border.all(
        color: vurgu?.withValues(alpha: 0.22) ?? Renkler.cizgi,
      ),
    );

ThemeData antrenorTemasi() {
  const taban = ColorScheme.dark(
    surface: Renkler.zemin,
    primary: Renkler.metin,
    secondary: Renkler.kurs,
    onSurface: Renkler.metin,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: taban,
    scaffoldBackgroundColor: Renkler.zemin,
    fontFamily: Yazi.aile,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Renkler.zemin,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: Yazi.baslik,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Renkler.yuzey,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Renkler.cizgiParlak,
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
    dividerTheme: const DividerThemeData(color: Renkler.cizgi, thickness: 1),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Renkler.amblemAcik),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Renkler.yuzeyYuksek,
      contentTextStyle: TextStyle(fontFamily: Yazi.aile, color: Renkler.metin),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
