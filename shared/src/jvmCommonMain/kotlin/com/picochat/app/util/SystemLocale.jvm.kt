package com.picochat.app.util

actual fun systemLanguage(): String = java.util.Locale.getDefault().language
