import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ═══════════════════════════════════════════════════════════════
// Cargar configuración de firma desde key.properties
// ═══════════════════════════════════════════════════════════════
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.velvetsync.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Configuración de firma (Signing Configs)
    // ═══════════════════════════════════════════════════════════════
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // 🔒 BUILD FLAVORS - Development & Production
    // ═══════════════════════════════════════════════════════════════
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Velvet Sync Dev")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "com.velvetsync.app"
            resValue("string", "app_name", "Velvet Sync")
        }
    }

    defaultConfig {
        applicationId = "com.velvetsync.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // 📦 ABI filters are handled by --split-per-abi flag
        // ndk.abiFilters removed to avoid conflict with splits

        // 📦 Excluir extensiones de Agora que NO usa este proyecto
        // El código solo usa el core RTC (init, joinChannel, mute, switchCamera, AgoraVideoView).
        // Todas las extensiones *_extension.so, códecs y herramientas auxiliares se eliminan.
        packagingOptions {
            exclude("lib/**/libagora_lip_sync_extension.so")
            exclude("lib/**/libagora-ffmpeg.so")
            exclude("lib/**/libagora_clear_vision_extension.so")
            exclude("lib/**/libagora_spatial_audio_extension.so")
            exclude("lib/**/libagora_ai_noise_suppression_extension.so")
            exclude("lib/**/libagora_face_capture_extension.so")
            exclude("lib/**/libagora_segmentation_extension.so")
            exclude("lib/**/libagora_ai_echo_cancellation_extension.so")
            exclude("lib/**/libagora_audio_beauty_extension.so")
            exclude("lib/**/libagora_content_inspection_extension.so")
            exclude("lib/**/libagora_screen_capture_extension.so")
            exclude("lib/**/libagora_video_quality_analyzer_extension.so")
            exclude("lib/**/libagora_video_av1_encoder_extension.so")
            exclude("lib/**/libagora_face_detection_extension.so")
            exclude("lib/**/libagora_video_encoder_extension.so")
            exclude("lib/**/libagora-fdkaac.so")
            exclude("lib/**/libagora-soundtouch.so")
        }
    }

    buildTypes {
        release {
            // Optimización y Seguridad
            val hasKeystore = keystorePropertiesFile.exists() && keystoreProperties.containsKey("storeFile")
            isMinifyEnabled = hasKeystore
            isShrinkResources = hasKeystore
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // ═══════════════════════════════════════════════════════════════
            // ✅ FIRMA DE RELEASE CONFIGURADA (P1 COMPLETADO)
            // ═══════════════════════════════════════════════════════════════
            // Firmado condicional: solo si existe key.properties con storeFile
            if (keystorePropertiesFile.exists() && keystoreProperties.containsKey("storeFile")) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            // Debug build configuration - usa signing config por defecto de Android
            isDebuggable = true
            // No usar signingConfigs.release para debug para evitar errores si no existe el keystore
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:35.1.0"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
