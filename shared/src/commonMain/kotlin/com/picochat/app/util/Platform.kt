package com.picochat.app.util

/** Short description of the native inference library (CPU features) or why it is missing. */
expect fun nativeInfo(): String

/** "android", "desktop" or "ios". */
expect val platformName: String
