// Root build: only declares plugins; modules apply them.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.detekt)
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("config/detekt/detekt.yml"))
    source.setFrom(files("app/src", "llama/src"))
}

tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }

// CI helper: copies the APK built by assembleRelease into dist/ with its final name.
// ./gradlew collectApk -PapkSrc=app-release.apk -PapkName=app-universal-release.apk
tasks.register<Copy>("collectApk") {
    val src = providers.gradleProperty("apkSrc")
    val name = providers.gradleProperty("apkName")
    from(layout.projectDirectory.dir("app/build/outputs/apk/release")) {
        include(src.get())
        rename { name.get() }
    }
    into(layout.projectDirectory.dir("dist"))
}
