package com.antrenorapp.antrenor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bildirimKanaliniOlustur()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL_PIL)
            .setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "muafMi" -> sonuc.success(pilMuafiyetiVarMi())
                    "ayarlariAc" -> sonuc.success(pilAyarlariniAc())
                    else -> sonuc.notImplemented()
                }
            }
    }

    /**
     * Android 8'den beri her bildirimin var olan bir kanala ait olmasi
     * gerekiyor. Sunucu bildirimleri "duyurular" kanalina gonderiyor ve
     * manifest de varsayilan kanal olarak bunu gosteriyor, ama kanali
     * hicbir yer olusturmuyordu.
     */
    private fun bildirimKanaliniOlustur() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val yonetici = getSystemService(NotificationManager::class.java) ?: return
        if (yonetici.getNotificationChannel(KANAL_KIMLIGI) != null) return

        val kanal = NotificationChannel(
            KANAL_KIMLIGI,
            "Federasyon duyurulari",
            // Yuksek onem: kurs ve vize duyurulari zamana bagli, kullanici
            // ekranin ustunde gormeli
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Takip edilen federasyonlarda yeni duyuru yayimlandiginda bildirir"
            enableVibration(true)
            setShowBadge(true)
        }
        yonetici.createNotificationChannel(kanal)
    }

    /** Uygulama pil optimizasyonundan muaf mi? */
    private fun pilMuafiyetiVarMi(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val guc = getSystemService(PowerManager::class.java) ?: return true
        return guc.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Kullaniciyi uygulamanin kendi ayar sayfasina goturur; oradan
     * "Pil -> Kisitlanmamis" secilir.
     *
     * Tek dokunuslu ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS penceresi
     * bilerek kullanilmiyor: o pencere kisitli bir izin istiyor ve Google
     * Play bunu yalnizca belirli kullanim durumlarinda kabul ediyor, bildirim
     * almak o listede degil. Uygulamanin reddedilmesi riskine deger.
     */
    private fun pilAyarlariniAc(): Boolean = try {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (hata: Exception) {
        // Bazi ureticilerde bu ekran yok; genel pil listesine dusuyoruz
        try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (ikinci: Exception) {
            false
        }
    }

    private companion object {
        // Sunucudaki push yukunde ve AndroidManifest'te ayni deger kullaniliyor
        const val KANAL_KIMLIGI = "duyurular"
        const val KANAL_PIL = "antrenor/pil"
    }
}
