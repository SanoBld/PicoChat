import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.compose.multiplatform)
}

val vName = providers.gradleProperty("versionName").orElse(providers.gradleProperty("appVersionName")).get()

// jpackage wants MAJOR.MINOR.PATCH, and macOS refuses a 0 major: 0.1.0 -> 1.1.0.
val pkgVersion = vName.substringBefore('-').split('.').let { p ->
    val major = p.getOrNull(0)?.toIntOrNull() ?: 1
    val minor = p.getOrNull(1)?.toIntOrNull() ?: 0
    val patch = p.getOrNull(2)?.toIntOrNull() ?: 0
    if (major == 0) "1.$minor.$patch" else "$major.$minor.$patch"
}

dependencies {
    implementation(project(":shared"))
    implementation(compose.desktop.currentOs)
}

compose.desktop {
    application {
        mainClass = "com.picochat.app.MainKt"
        nativeDistributions {
            targetFormats(TargetFormat.Dmg, TargetFormat.Exe, TargetFormat.Deb, TargetFormat.Rpm)
            packageName = "PicoChat"
            packageVersion = pkgVersion
            description = "Private AI chat that runs 100% on your device"
            vendor = "PicoChat"
            includeAllModules = true
            // native-libs/<os>-<arch>/ holds libpicochat_llama (built by CI, see native/desktop)
            appResourcesRootDir.set(layout.projectDirectory.dir("native-libs"))
            windows {
                iconFile.set(file("icons/icon.ico"))
                menuGroup = "PicoChat"
                shortcut = true
                dirChooser = true
                upgradeUuid = "8d2f0a64-5b0e-4f7e-9a1c-7a3d6f5e2b10"
            }
            macOS {
                iconFile.set(file("icons/icon.icns"))
                bundleID = "com.picochat.app"
            }
            linux {
                iconFile.set(file("icons/icon.png"))
                menuGroup = "Utility"
            }
        }
    }
}
