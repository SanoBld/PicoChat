package com.picochat.app.util

import platform.Foundation.NSLocale
import platform.Foundation.currentLocale
import platform.Foundation.languageCode

actual fun systemLanguage(): String = NSLocale.currentLocale.languageCode ?: "en"
