import java.util.Properties

// Yayin imzalama bilgileri depoya girmiyor: key.properties .gitignore'da,
// anahtar dosyasi da depo disinda duruyor. Dosya yoksa (baska bir makinede
// veya CI'da) derleme hata ika etmez, hata ayiklama anahtariyla imzalanir.
val imzaAyarlari = Properties().apply {
    val dosya = rootProject.file("key.properties")
    if (dosya.exists()) dosya.inputStream().use { load(it) }
}
val yayinImzasiVar = imzaAyarlari.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.antrenorapp.antrenor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications, eski Android surumlerinde java.time
        // kullanabilmek icin bunu sart kosuyor
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.antrenorapp.antrenor"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (yayinImzasiVar) {
            create("yayin") {
                storeFile = file(imzaAyarlari.getProperty("storeFile"))
                storePassword = imzaAyarlari.getProperty("storePassword")
                keyAlias = imzaAyarlari.getProperty("keyAlias")
                keyPassword = imzaAyarlari.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Hata ayiklama anahtari herkeste ayni oldugu icin magaza bunu
            // reddediyor; ayrica sahte "guncelleme" paketi uretilebiliyor.
            signingConfig = if (yayinImzasiVar) {
                signingConfigs.getByName("yayin")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // play-services-ads, androidx.work 2.7.0'i (Room 2.2.5) getiriyor; bu surum
    // R8 ile birlikte acilista "Failed to create an instance of WorkDatabase"
    // hatasi veriyor. Guncel surum zorlanarak cozuluyor.
    implementation("androidx.work:work-runtime:2.10.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
