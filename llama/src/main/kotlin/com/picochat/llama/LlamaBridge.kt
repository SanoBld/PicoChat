package com.picochat.llama

/** Kotlin side of the llama.cpp JNI bridge. */
object LlamaBridge {
    init { System.loadLibrary("picochat_llama") }

    external fun systemInfo(): String
}
