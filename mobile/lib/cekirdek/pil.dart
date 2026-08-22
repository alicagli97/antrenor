import 'dart:io';

import 'package:flutter/services.dart';

/// Pil optimizasyonu köprüsü.
///
/// Android üreticileri (özellikle Xiaomi, nubia/REDMAGIC, Huawei, Oppo)
/// arka plandaki uygulamaları agresif biçimde durduruyor. Uygulama
/// kısıtlandığında Firebase bildirimleri ya çok gecikiyor ya hiç gelmiyor.
/// Kullanıcıyı kendi pil ayarına yönlendirip bu kısıtı kaldırmasını
/// istiyoruz.
class Pil {
  static const _kanal = MethodChannel('antrenor/pil');

  static bool get desteklenir => Platform.isAndroid;

  /// Uygulama pil optimizasyonundan muaf mı? iOS'ta ve hata durumunda,
  /// gereksiz uyarı çıkmasın diye true kabul edilir.
  static Future<bool> muafMi() async {
    if (!desteklenir) return true;
    try {
      return await _kanal.invokeMethod<bool>('muafMi') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Uygulamanın sistem ayar sayfasını açar (Pil → Kısıtlanmamış).
  static Future<bool> ayarlariAc() async {
    if (!desteklenir) return false;
    try {
      return await _kanal.invokeMethod<bool>('ayarlariAc') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
