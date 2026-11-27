package com.picochat.app.ui.theme

import android.os.Build
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import com.picochat.app.util.AndroidContext

actual fun dynamicColorScheme(dark: Boolean): ColorScheme? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
    val ctx = AndroidContext.app
    return if (dark) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
}
