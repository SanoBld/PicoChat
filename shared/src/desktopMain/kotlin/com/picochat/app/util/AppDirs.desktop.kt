package com.picochat.app.util

actual fun appDataDir(): String {
    val os = System.getProperty("os.name").orEmpty().lowercase()
    val home = System.getProperty("user.home").orEmpty()
    val base = when {
        "win" in os -> System.getenv("APPDATA") ?: "$home/AppData/Roaming"
        "mac" in os -> "$home/Library/Application Support"
        else -> System.getenv("XDG_DATA_HOME") ?: "$home/.local/share"
    }
    return "$base/PicoChat"
}
