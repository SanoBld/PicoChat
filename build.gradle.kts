// Root build: declares plugins only; modules apply them.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.compose.multiplatform) apply false
    alias(libs.plugins.detekt)
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("config/detekt/detekt.yml"))
    source.setFrom(files("shared/src", "androidApp/src", "desktopApp/src"))
}

tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }

// CI helper: copies a file produced by a build into dist/ with its final name.
//   ./gradlew collectFile -PfileDir=androidApp/build/outputs/apk/release -PfileSrc=androidApp-release.apk -PfileName=x.apk
tasks.register<Copy>("collectFile") {
    val dir = providers.gradleProperty("fileDir")
    val src = providers.gradleProperty("fileSrc")
    val name = providers.gradleProperty("fileName")
    from(layout.projectDirectory.dir(dir.get())) {
        include(src.get())
        rename { name.get() }
    }
    into(layout.projectDirectory.dir("dist"))
}
