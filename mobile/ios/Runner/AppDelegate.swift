import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Yerel hatirlatmalar on planda da gorunsun. Firebase Messaging kendi
    // temsilcisini kuruyor; bunu yazmayinca zamanlanan bildirim sessizce
    // dusuyor ve kullanici hicbir sey gormuyor.
    //
    // Atama super'dan SONRA yapiliyor: eklentiler super icinde kaydoluyor,
    // once yazarsak Firebase bizimkini eziyor. FlutterAppDelegate zaten
    // UNUserNotificationCenterDelegate'i uyguluyor ve eklentilere iletiyor.
    let sonuc = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    return sonuc
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
