package com.picochat.app.util

import com.picochat.llama.LlamaBridge

actual fun nativeInfo(): String = LlamaBridge.info()

actual val platformName: String = if (System.getProperty("java.vm.name").orEmpty().contains("Dalvik") ||
    System.getProperty("java.vendor").orEmpty().contains("Android")) "android" else "desktop"
