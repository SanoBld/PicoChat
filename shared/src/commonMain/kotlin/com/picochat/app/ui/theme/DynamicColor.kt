package com.picochat.app.ui.theme

import androidx.compose.material3.ColorScheme

/** Material You colours from the wallpaper. Null where the system does not offer them (all but Android 12+). */
expect fun dynamicColorScheme(dark: Boolean): ColorScheme?
