# R8 tam kip (full mode) Room'un urettigi veritabani siniflarinin parametresiz
# yapicisini siliyor; WorkManager bu yapiciyi yansima ile cagirdigi icin
# uygulama acilista cokuyordu:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# WorkManager play-services-ads uzerinden geliyor.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keepclassmembers class * extends androidx.room.RoomDatabase { <init>(); }

# Play Faturalandirma: yanit modelleri yansima ile okunuyor
-keep class com.android.vending.billing.** { *; }
