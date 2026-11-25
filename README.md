# PicoChat (Kotlin)

Private AI chat that runs 100% on your device. Native Android rewrite (Kotlin, Jetpack Compose,
Material 3) of the Flutter app. Models are GGUF files from Hugging Face run by llama.cpp (JNI).

## Layout

```
app/    UI (Compose), data, domain, engine, Android services
llama/  JNI module: llama.cpp fetched by CMake at a pinned tag
docs/   PORTING.md = Flutter file -> Kotlin file map and progress
.github/workflows/  build-android, build-all, ci, release
```

## Build

```
./gradlew assembleDebug      # needs JDK 17, Android SDK 36, NDK 29, CMake 3.22.1
./gradlew testDebugUnitTest detekt
```

Debug and release share `app/debug.keystore`, so every APK has the same signature.

## Release

Add a section to `CHANGELOG.md`, then push a tag `vX.Y.Z` (or run *Release PicoChat* from the Actions tab).
APKs: `app-universal-release.apk`, `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`.

## Languages

`app/src/main/res/values{,-fr,-es,-de}/strings.xml`. Use `tr("key", mapOf("name" to x))`.
