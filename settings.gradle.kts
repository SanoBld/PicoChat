pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "PicoChat"

// Android modules need the Android SDK + NDK. They are only part of the build when
//   - -Ppico.android=true is passed (the Android workflow does), or
//   - local.properties has sdk.dir (a developer machine with Android Studio).
// Desktop / iOS / CI jobs without the SDK build fine without them.
val localProps = java.util.Properties().apply {
    val f = file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val androidEnabled = providers.gradleProperty("pico.android").map { it.toBoolean() }
    .getOrElse(localProps.getProperty("sdk.dir") != null)
gradle.extra["picoAndroid"] = androidEnabled

include(":shared", ":desktopApp")
if (androidEnabled) include(":androidApp", ":llama")
