# llama.cpp on iOS

Status: not linked yet (the iOS app starts and shows "not linked yet").

Plan:
1. `native/ios/build-xcframework.sh` builds `llama.xcframework` with the script shipped in llama.cpp.
2. `shared/src/nativeInterop/cinterop/llama.def` exposes `llama.h` to Kotlin/Native.
3. `shared/src/iosMain` gets an `IosLlamaEngine` implementing `InferenceEngine`.
