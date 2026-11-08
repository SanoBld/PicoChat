plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.picochat.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        // Persistent keystore committed to the repo (same one as LastStats).
        // rootProject.file() resolves relative to the android/ directory.
        create("localDebug") {
            storeFile     = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias      = "androiddebugkey"
            keyPassword   = "android"
        }
    }

    defaultConfig {
        applicationId = "com.picochat.app"
        minSdk        = flutter.minSdkVersion
        targetSdk     = flutter.targetSdkVersion
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        // Debug and release use the same committed keystore,
        // so every APK (local or CI) has an identical signature.
        debug {
            signingConfig = signingConfigs.getByName("localDebug")
        }
        release {
            signingConfig = signingConfigs.getByName("localDebug")
            isShrinkResources = false
            isMinifyEnabled   = false
        }
    }
}

flutter {
    source = "../.."
}
