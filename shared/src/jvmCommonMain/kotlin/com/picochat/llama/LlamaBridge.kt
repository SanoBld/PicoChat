package com.picochat.llama

import java.io.File

/** Receives the generated text; return false to stop the generation. */
fun interface TokenCallback {
    fun onToken(bytes: ByteArray): Boolean
}

/**
 * Kotlin side of the llama.cpp JNI bridge (Android + desktop).
 * Android: libpicochat_llama.so comes from the :llama module.
 * Desktop: the library sits in the app resources folder (desktopApp/native-libs/<os>-<arch>).
 */
object LlamaBridge {
    private val loaded: Result<Unit> = runCatching { loadLibrary() }

    private fun loadLibrary() {
        try {
            System.loadLibrary("picochat_llama")
            return
        } catch (_: UnsatisfiedLinkError) {
            // not on the library path: try the packaged resources folder (desktop)
        }
        val dir = System.getProperty("compose.application.resources.dir") ?: error("picochat_llama not found")
        System.load(File(dir, System.mapLibraryName("picochat_llama")).absolutePath)
    }

    val isAvailable: Boolean get() = loaded.isSuccess

    /** Why the library is missing (null when it loaded). */
    val loadError: String? get() = loaded.exceptionOrNull()?.message

    @JvmStatic external fun systemInfo(): String

    /** Returns a handle, or throws IllegalStateException. Strings are UTF-8 bytes. */
    @JvmStatic external fun nativeLoad(path: ByteArray, contextSize: Int, threads: Int): Long

    @JvmStatic external fun nativeGenerate(
        handle: Long,
        roles: Array<String>,
        contents: Array<ByteArray>,
        temperature: Float,
        maxTokens: Int,
        callback: TokenCallback,
    )

    @JvmStatic external fun nativeStop(handle: Long)

    @JvmStatic external fun nativeFree(handle: Long)

    /** Safe text for the UI: CPU features, or the reason the library did not load. */
    fun info(): String = loaded.fold(onSuccess = { systemInfo() }, onFailure = { "native library: ${it.message}" })
}
