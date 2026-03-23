import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
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
            applicationIdSuffix = ".dev"
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Optimización y Seguridad
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")

            // ═══════════════════════════════════════════════════════════════
            // ✅ FIRMA DE RELEASE CONFIGURADA (P1 COMPLETADO)
            // ═══════════════════════════════════════════════════════════════
            signingConfig = signingConfigs.getByName("release")
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
