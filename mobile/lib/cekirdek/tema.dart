import 'package:flutter/material.dart';

/// Uygulama teması. Renkler logodan alındı: siyah zemin, gri yüzeyler,
/// beyaz metin. Kategoriler tek renkle değil, ayırt edici tonlarla gösterilir.
class Renkler {
  static const zemin = Color(0xFF000205); // logo zemini
  static const yuzey = Color(0xFF101418);
  static const yuzeyAcik = Color(0xFF171C22);
  static const cizgi = Color(0xFF232A32);

  static const metin = Color(0xFFF3F3F3); // logo yazısı
  static const metinIkincil = Color(0xFFA8B0B9);
  static const metinSolgun = Color(0xFF6C7681);

  static const amblemAcik = Color(0xFFC6C6C6);
  static const amblemOrta = Color(0xFF7D7D7D);

  /// Kategori renkleri — akışta göz taraması için
  static const kurs = Color(0xFFE0A33C); // antrenörü ilgilendiren: öne çıksın
  static const musabaka = Color(0xFF5B9BD5);
  static const mevzuat = Color(0xFF9B8CD5);
  static const takvim = Color(0xFF57B894);
  static const duyuru = Color(0xFF8A939D);

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
}

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
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Renkler.zemin,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Renkler.metin,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Renkler.yuzey,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Renkler.yuzeyAcik,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (durum) => TextStyle(
          fontSize: 11.5,
          fontWeight: durum.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
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
    chipTheme: const ChipThemeData(
      backgroundColor: Renkler.yuzey,
      side: BorderSide(color: Renkler.cizgi),
      labelStyle: TextStyle(color: Renkler.metinIkincil, fontSize: 13),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Renkler.amblemAcik),
  );
}
