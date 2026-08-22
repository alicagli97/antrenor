import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ödüllü reklam katmanı.
///
/// Ücretsiz kullanıcı bir duyuruyu açarken kısa bir reklam izler; premium
/// kullanıcıya hiç reklam gösterilmez. Reklam gelmezse içerik yine de açılır:
/// reklam sunucusuna ulaşılamadığı için uygulamanın kilitlenmesi hem kullanıcı
/// için hem de mağaza incelemesi için kabul edilemez.
class Reklam {
  /// Yayın kimliği: pub-4393007832677575
  ///
  /// [testModu] açıkken Google'ın resmî test birimleri kullanılır: gerçek
  /// reklam gösterilmez, geçersiz tıklama sayılmaz, hesap kapanma riski olmaz.
  /// Play'de yayına çıkarken false yapılacak — uygulama mağazada listelenene
  /// kadar AdMob zaten gerçek reklam sunmuyor, o yüzden acelesi yok.
  static const bool testModu = true;

  static const _testOdulluAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testOdulluIos = 'ca-app-pub-3940256099942544/1712485313';
  static const _gercekOdulluAndroid =
      'ca-app-pub-4393007832677575/4879838845';
  static const _gercekOdulluIos = 'ca-app-pub-4393007832677575/6168869788';

  /// Gerçek reklamlara geçildikten sonra geliştirme/test telefonlarının
  /// kimlikleri buraya yazılır; bu cihazlara test reklamı gider ve gösterim
  /// sayılmaz. Kendi telefonunda gerçek reklama dokunmak "geçersiz trafik"
  /// sayılıp hesabın kapanmasına yol açabiliyor.
  ///
  /// Kimlik, uygulama cihazda çalışırken logcat'te şu satırda görünür:
  ///   "Use RequestConfiguration.Builder.setTestDeviceIds(...)"
  static const testCihazlari = <String>[];

  static bool _acildi = false;
  static RewardedAd? _hazirReklam;
  static bool _yukleniyor = false;
  static int _artArdaHata = 0;

  static bool get _desteklenir => Platform.isAndroid || Platform.isIOS;

  static String get _odulluKimlik {
    if (Platform.isIOS) {
      return testModu || _gercekOdulluIos.isEmpty
          ? _testOdulluIos
          : _gercekOdulluIos;
    }
    return testModu || _gercekOdulluAndroid.isEmpty
        ? _testOdulluAndroid
        : _gercekOdulluAndroid;
  }

  static Future<void> baslat() async {
    if (!_desteklenir || _acildi) return;
    try {
      await _rizaAl();
      await MobileAds.instance.initialize();
      if (testCihazlari.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(testDeviceIds: testCihazlari));
      }
      _acildi = true;
      onYukle();
    } catch (_) {
      _acildi = false;
    }
  }

  /// Rıza (UMP) akışı. Avrupa'daki kullanıcıya, AdMob panelinde tanımlanan
  /// rıza formu gösterilir; Türkiye'deki kullanıcıya hiçbir şey çıkmaz.
  /// Form gösterilmezse Google kişiselleştirilmiş reklam sunmuyor, bu da
  /// doğrudan gelir kaybı demek.
  ///
  /// Hata veya gecikme akışı durdurmaz: rıza alınamasa da reklam kütüphanesi
  /// kurulur, yalnızca kişiselleştirilmemiş reklam gelir.
  static Future<void> _rizaAl() async {
    final tamamlandi = Completer<void>();
    void bitir() {
      if (!tamamlandi.isCompleted) tamamlandi.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) => bitir());
          bitir();
        },
        (_) => bitir(),
      );
    } catch (_) {
      bitir();
    }

    await tamamlandi.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  /// Bir sonraki reklamı önden yükler; kullanıcı beklemesin diye.
  static void onYukle() {
    if (!_acildi || _yukleniyor || _hazirReklam != null) return;
    _yukleniyor = true;
    RewardedAd.load(
      adUnitId: _odulluKimlik,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (reklam) {
          _hazirReklam = reklam;
          _yukleniyor = false;
          _artArdaHata = 0;
        },
        onAdFailedToLoad: (_) {
          _yukleniyor = false;
          _artArdaHata++;
          // Üst üste başarısızlıkta artan aralıkla tekrar denenir
          if (_artArdaHata <= 3) {
            Timer(Duration(seconds: 5 * _artArdaHata), onYukle);
          }
        },
      ),
    );
  }

  static bool get reklamHazir => _hazirReklam != null;

  /// Ödüllü reklamı gösterir. Dönen değer "içerik açılabilir mi" demektir:
  /// reklam izlendiğinde de, reklam hiç bulunamadığında da true döner.
  static Future<bool> odulluGoster() async {
    // Kutuphane acilista degil, ilk ihtiyacta kuruluyor olabilir
    if (!_acildi) await baslat();
    if (!_acildi) return true;

    if (_hazirReklam == null) {
      onYukle();
      // En fazla ~4 saniye bekleriz; gelmezse kullanıcıyı bekletmeyiz
      for (var i = 0; i < 20 && _hazirReklam == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    final reklam = _hazirReklam;
    if (reklam == null) return true;
    _hazirReklam = null;

    final tamamlandi = Completer<bool>();
    var odulKazanildi = false;

    reklam.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onYukle();
        if (!tamamlandi.isCompleted) tamamlandi.complete(odulKazanildi);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        onYukle();
        if (!tamamlandi.isCompleted) tamamlandi.complete(true);
      },
    );

    try {
      await reklam.show(
          onUserEarnedReward: (ad, odul) => odulKazanildi = true);
    } catch (_) {
      if (!tamamlandi.isCompleted) tamamlandi.complete(true);
    }
    return tamamlandi.future;
  }

  /// Premium'a geçildiğinde bellekteki reklam bırakılır.
  static void temizle() {
    _hazirReklam?.dispose();
    _hazirReklam = null;
  }
}
