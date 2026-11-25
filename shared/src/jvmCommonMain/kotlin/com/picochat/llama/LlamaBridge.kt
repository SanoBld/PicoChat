package com.picochat.llama

import java.io.File

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

    @JvmStatic
    external fun systemInfo(): String

    /** Safe text for the UI: CPU features, or the reason the library did not load. */
    fun info(): String = loaded.fold(onSuccess = { systemInfo() }, onFailure = { "native library: ${it.message}" })
}
