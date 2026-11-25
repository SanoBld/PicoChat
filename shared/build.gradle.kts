plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Set in settings.gradle.kts: false when the Android SDK is not available.
val androidEnabled = gradle.extra["picoAndroid"] as Boolean
if (androidEnabled) apply(plugin = "com.android.library")

kotlin {
    if (androidEnabled) {
        androidTarget {
            compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
        }
    }
    jvm("desktop")
    listOf(iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    sourceSets {
        // Code shared by Android and desktop (JVM): the JNI bridge to llama.cpp.
        val jvmCommonMain by creating { dependsOn(commonMain.get()) }
        val desktopMain by getting { dependsOn(jvmCommonMain) }
        if (androidEnabled) {
            named("androidMain") {
                dependsOn(jvmCommonMain)
                dependencies {
                    implementation(libs.androidx.activity.compose)
                    implementation(libs.androidx.core.ktx)
                    implementation(libs.androidx.work)
                    implementation(libs.coroutines.android)
                    implementation(libs.ktor.okhttp)
                }
            }
        }

        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.materialIconsExtended)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(libs.coroutines.core)
            implementation(libs.serialization.json)
            implementation(libs.datetime)
            implementation(libs.ktor.core)
            implementation(libs.coil.compose)
            implementation(libs.coil.svg)
            implementation(libs.coil.network)
        }
        desktopMain.dependencies {
            implementation(compose.desktop.currentOs)
            implementation(libs.coroutines.swing)
            implementation(libs.ktor.okhttp)
        }
        iosMain.dependencies { implementation(libs.ktor.darwin) }
        commonTest.dependencies {
            implementation(kotlin("test"))
            implementation(libs.coroutines.test)
            implementation(libs.ktor.mock)
        }
    }
}

if (androidEnabled) {
    extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
        namespace = "com.picochat.shared"
        compileSdk = 36
        defaultConfig { minSdk = 26 }
        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}

compose.resources {
    publicResClass = true
    packageOfResClass = "com.picochat.app.resources"
}
