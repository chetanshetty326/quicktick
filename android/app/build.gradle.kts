import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load signing credentials from android/key.properties (never commit this file)
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.quicktick.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = keyPropertiesFile.parentFile.resolve(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }

    defaultConfig {
        // Unique Default Application ID
        applicationId = "com.quicktick.app"
        // image_picker_android v0.8.13+17 requires API 24 (Android 7.0) minimum
        // flutter_secure_storage v9+ also satisfied by API 24+
        // Flutter 3.41+ is dropping API 23 support — 24 is the safe floor
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "Quick Tick"
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
        }
    }

    flavorDimensions += "default"

    productFlavors {
        create("customer") {
            dimension = "default"
            applicationId = "com.quicktick.customer"
            manifestPlaceholders["appName"] = "Quick Tick"
        }
        create("retailer") {
            dimension = "default"
            applicationId = "com.quickmart.partner"
            manifestPlaceholders["appName"] = "Quick Mart"
        }
        create("delivery") {
            dimension = "default"
            applicationId = "com.quickreach.delivery"
            manifestPlaceholders["appName"] = "Quick Reach"
        }
    }

    buildTypes {
        release {
            // Use production keystore — no longer using debug signing
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

tasks.matching { it.name.startsWith("uploadCrashlytics") }.configureEach {
    enabled = false
}
