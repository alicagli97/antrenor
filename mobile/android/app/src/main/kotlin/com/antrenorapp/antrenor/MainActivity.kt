package com.antrenorapp.antrenor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bildirimKanaliniOlustur()
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

    private companion object {
        // Sunucudaki push yukunde ve AndroidManifest'te ayni deger kullaniliyor
        const val KANAL_KIMLIGI = "duyurular"
    }
}
