plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// -PversionName=1.2.3 -PversionCode=42 (CI) or the defaults in gradle.properties.
val vName = providers.gradleProperty("versionName").orElse(providers.gradleProperty("appVersionName")).get()
val vCode = providers.gradleProperty("versionCode").orElse(providers.gradleProperty("appVersionCode")).get().toInt()

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

android {
    namespace = "com.picochat.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.picochat.app"
        minSdk = 26
        targetSdk = 36
        versionCode = vCode
        versionName = vName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        // Same committed keystore for debug and release: every APK has the same signature.
        create("shared") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
    buildTypes {
        debug { signingConfig = signingConfigs.getByName("shared") }
        release {
            signingConfig = signingConfigs.getByName("shared")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    // One universal APK + one per CPU architecture (names are read by the in-app updater).
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    androidResources { localeFilters += listOf("en", "fr", "es", "de") }
    lint { abortOnError = false; checkReleaseBuilds = false }
}

dependencies {
    implementation(project(":shared"))
    implementation(project(":llama")) // native libpicochat_llama.so
    implementation(libs.androidx.activity.compose)
    androidTestImplementation(libs.androidx.test.ext)
    androidTestImplementation(libs.androidx.test.espresso)
}
