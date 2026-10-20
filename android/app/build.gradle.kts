import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use(localProperties::load)
}
val googleMapsApiKey = localProperties.getProperty("MAPS_API_KEY", "")

android {
    namespace = "com.vigiaia.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        manifestPlaceholders["MAPS_API_KEY"] = googleMapsApiKey
        applicationId = "com.vigiaia.app"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // No CI otimizado, uma unica tarefa Gradle gera o APK universal e os tres APKs por ABI.
    // Builds locais continuam com o comportamento padrao do Flutter.
    val multiApkCi = providers.environmentVariable("VIGIAIA_CI_MULTI_APK").orNull == "1"
    if (multiApkCi) {
        splits {
            abi {
                isEnable = true
                reset()
                include("armeabi-v7a", "arm64-v8a", "x86_64")
                isUniversalApk = true
            }
        }
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
            val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")

            if (keystorePath.isNullOrBlank() || keystorePassword.isNullOrBlank() ||
                keyAliasValue.isNullOrBlank() || keyPasswordValue.isNullOrBlank()) {
                throw GradleException("Secrets de assinatura release ausentes. Configure ANDROID_KEYSTORE_BASE64/PASSWORD/ALIAS/KEY_PASSWORD no GitHub.")
            }

            storeFile = rootProject.file(keystorePath)
            storePassword = keystorePassword
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Correção APK 260: R8 mantém a minificação e respeita somente
            // scripts ML Kit opcionais ausentes (OCR Latin permanece funcional).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Serviço de câmera nativo MCRP/NotificationCompat, migrado do Minha Câmera.
    implementation("androidx.core:core-ktx:1.13.1")
    // Rádio online: ExoPlayer (MP3/AAC/Ogg/HLS com metadados ICY) e MediaSession.
    implementation("androidx.media3:media3-exoplayer:1.8.0")
    implementation("androidx.media3:media3-exoplayer-rtsp:1.8.0")
    implementation("androidx.media3:media3-ui:1.8.0")
    implementation("androidx.media3:media3-exoplayer-hls:1.8.0")
    implementation("androidx.media3:media3-session:1.8.0")
}

flutter {
    source = "../.."
}
