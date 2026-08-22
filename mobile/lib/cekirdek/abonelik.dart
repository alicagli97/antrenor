import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium abonelik.
///
/// Ödeme tamamen mağaza üzerinden yürür (Play Faturalandırma / Apple IAP);
/// dijital abonelik için her iki mağaza da bunu zorunlu tutuyor. Kendi
/// sunucumuz ve hesap sistemimiz olmadığından hak sahipliği cihazda saklanır
/// ve açılışta mağazadan doğrulanır.
class Abonelik extends ChangeNotifier {
  static final Abonelik ornek = Abonelik._();
  Abonelik._();

  /// Play Console ve App Store Connect'te birebir bu kimliklerle tanımlanmalı
  static const aylik = 'antrenor_premium_aylik';
  static const yillik = 'antrenor_premium_yillik';
  static const kimlikler = <String>{aylik, yillik};

  final InAppPurchase _magaza = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _dinleyici;

  /// Test sürümü bayrağı. Yalnızca şu komutla derlenen pakette açık olur:
  ///   flutter build apk --release --dart-define=TEST_PREMIUM=true
  ///
  /// Mağazaya gidecek normal derlemede bu sabit false olduğu için aşağıdaki
  /// kısayol derleyici tarafından tamamen atılır: yayınlanan uygulamada
  /// premium'u bedava açan hiçbir yol bulunmaz.
  static const testPremium = bool.fromEnvironment('TEST_PREMIUM');

  /// Mağazadan doğrulanmış hak sahipliği
  bool _magazadan = false;

  bool get premium => testPremium || _magazadan;

  bool magazaHazir = false;
  bool islemde = false;
  List<ProductDetails> urunler = const [];
  String? sonHata;

  bool _dogrulamadaBulundu = false;

  ProductDetails? get aylikUrun => _urun(aylik);
  ProductDetails? get yillikUrun => _urun(yillik);

  ProductDetails? _urun(String kimlik) {
    for (final u in urunler) {
      if (u.id == kimlik) return u;
    }
    return null;
  }

  Future<void> baslat() async {
    final kayit = await SharedPreferences.getInstance();
    _magazadan = kayit.getBool('premium') ?? false;
    notifyListeners();

    try {
      magazaHazir = await _magaza.isAvailable();
    } catch (_) {
      magazaHazir = false;
    }
    if (!magazaHazir) return;

    _dinleyici = _magaza.purchaseStream.listen(
      _islemleriIsle,
      onError: (_) {
        sonHata = 'Mağaza bağlantısında sorun oluştu';
        islemde = false;
        notifyListeners();
      },
    );

    await urunleriGetir();

    // Play, etkin abonelikleri cihazdan döndürdüğü için Android'de açılışta
    // sessizce doğrulanabiliyor: aboneliği biten kullanıcı premium kalmaz.
    // iOS'ta geri yükleme Apple Kimliği sorabildiğinden kendiliğinden
    // çağrılmaz; orada Ayarlar'daki "Satın alımları geri yükle" kullanılır.
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_sessizDogrula());
    }
  }

  Future<void> urunleriGetir() async {
    if (!magazaHazir) return;
    try {
      final yanit = await _magaza.queryProductDetails(kimlikler);
      urunler = yanit.productDetails;
    } catch (_) {
      urunler = const [];
    }
    notifyListeners();
  }

  /// Satın alma. Abonelikler de "tüketilmeyen ürün" olarak satın alınır.
  Future<void> satinAl(ProductDetails urun) async {
    if (!magazaHazir) {
      sonHata = 'Mağazaya ulaşılamıyor';
      notifyListeners();
      return;
    }
    sonHata = null;
    islemde = true;
    notifyListeners();
    try {
      await _magaza.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: urun));
    } catch (e) {
      islemde = false;
      sonHata = 'Satın alma başlatılamadı';
      notifyListeners();
    }
  }

  /// Kullanıcının başlattığı geri yükleme. Apple, abonelik satan her
  /// uygulamada bu düğmenin bulunmasını şart koşuyor.
  Future<void> geriYukle() async {
    if (!magazaHazir) {
      sonHata = 'Mağazaya ulaşılamıyor';
      notifyListeners();
      return;
    }
    sonHata = null;
    islemde = true;
    notifyListeners();
    try {
      await _magaza.restorePurchases();
    } catch (_) {
      sonHata = 'Geri yükleme yapılamadı';
    }
    // Geri yüklemenin bittiğine dair ayrı bir sinyal yok; sonuçlar akıştan
    // gelir. Kısa bir bekleme sonunda durumu serbest bırakıyoruz.
    await Future<void>.delayed(const Duration(seconds: 4));
    islemde = false;
    notifyListeners();
  }

  Future<void> _sessizDogrula() async {
    _dogrulamadaBulundu = false;
    try {
      await _magaza.restorePurchases();
    } catch (_) {
      return; // bağlantı yoksa mevcut hak sahipliğine dokunmuyoruz
    }
    await Future<void>.delayed(const Duration(seconds: 6));
    if (!_dogrulamadaBulundu && _magazadan) {
      await _premiumYaz(false);
    }
  }

  Future<void> _islemleriIsle(List<PurchaseDetails> islemler) async {
    for (final islem in islemler) {
      final durum = islem.status;

      if (durum == PurchaseStatus.pending) {
        islemde = true;
      } else if (durum == PurchaseStatus.error) {
        islemde = false;
        sonHata = islem.error?.message ?? 'Satın alma tamamlanamadı';
      } else if (durum == PurchaseStatus.canceled) {
        islemde = false;
      } else if (durum == PurchaseStatus.purchased ||
          durum == PurchaseStatus.restored) {
        islemde = false;
        if (kimlikler.contains(islem.productID)) {
          _dogrulamadaBulundu = true;
          await _premiumYaz(true);
        }
      }

      // Tamamlanmayan işlem mağazada askıda kalır ve para iadesine döner
      if (islem.pendingCompletePurchase) {
        await _magaza.completePurchase(islem);
      }
    }
    notifyListeners();
  }

  Future<void> _premiumYaz(bool deger) async {
    if (_magazadan == deger) return;
    _magazadan = deger;
    final kayit = await SharedPreferences.getInstance();
    await kayit.setBool('premium', deger);
    notifyListeners();
  }

  @override
  void dispose() {
    _dinleyici?.cancel();
    super.dispose();
  }
}
