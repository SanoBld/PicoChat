package com.picochat.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.picochat.app.data.store.Prefs
import com.picochat.app.resources.Res
import com.picochat.app.resources.google_sans_flex_24pt_bold
import com.picochat.app.resources.google_sans_flex_24pt_light
import com.picochat.app.resources.google_sans_flex_24pt_medium
import com.picochat.app.resources.google_sans_flex_24pt_regular
import org.jetbrains.compose.resources.Font

/** Accent choices of the appearance settings: translation key to colour. */
val accentChoices: List<Pair<String, Int>> = listOf(
    "accent_teal" to 0xFF0F766E.toInt(),
    "accent_blue" to 0xFF1E5FD1.toInt(),
    "accent_purple" to 0xFF6750A4.toInt(),
    "accent_green" to 0xFF2E7D32.toInt(),
    "accent_red" to 0xFFC62828.toInt(),
    "accent_orange" to 0xFFEF6C00.toInt(),
    "accent_pink" to 0xFFD81B60.toInt(),
    "accent_neutral" to 0xFF5F6368.toInt(),
)

@Composable
private fun picoTypography(): Typography {
    val family = FontFamily(
        Font(Res.font.google_sans_flex_24pt_light, FontWeight.Light),
        Font(Res.font.google_sans_flex_24pt_regular, FontWeight.Normal),
        Font(Res.font.google_sans_flex_24pt_medium, FontWeight.Medium),
        Font(Res.font.google_sans_flex_24pt_bold, FontWeight.Bold),
    )
    fun TextStyle.f() = copy(fontFamily = family)
    val d = Typography()
    return d.copy(
        displayLarge = d.displayLarge.f(), displayMedium = d.displayMedium.f(), displaySmall = d.displaySmall.f(),
        headlineLarge = d.headlineLarge.f(), headlineMedium = d.headlineMedium.f(), headlineSmall = d.headlineSmall.f(),
        titleLarge = d.titleLarge.f(), titleMedium = d.titleMedium.f(), titleSmall = d.titleSmall.f(),
        bodyLarge = d.bodyLarge.f(), bodyMedium = d.bodyMedium.f(), bodySmall = d.bodySmall.f(),
        labelLarge = d.labelLarge.f(), labelMedium = d.labelMedium.f(), labelSmall = d.labelSmall.f(),
    )
}

@Composable
fun PicoTheme(content: @Composable () -> Unit) {
    val dark = when (Prefs.themeMode.value) {
        "light" -> false
        "dark" -> true
        else -> isSystemInDarkTheme()
    }
    val accent = Color(Prefs.accent.value)
    val scheme = if (dark) {
        val base = Color(0xFF101413)
        darkColorScheme(
            primary = lerp(accent, Color.White, 0.35f),
            onPrimary = Color(0xFF0B0F0E),
            primaryContainer = lerp(base, accent, 0.45f),
            onPrimaryContainer = Color.White,
            secondaryContainer = lerp(base, accent, 0.25f),
            background = base,
            surface = base,
            surfaceVariant = lerp(base, accent, 0.14f),
            surfaceContainer = lerp(base, accent, 0.08f),
        )
    } else {
        lightColorScheme(
            primary = accent,
            onPrimary = Color.White,
            primaryContainer = lerp(Color.White, accent, 0.18f),
            onPrimaryContainer = lerp(Color.Black, accent, 0.6f),
            secondaryContainer = lerp(Color.White, accent, 0.12f),
            background = lerp(Color.White, accent, 0.03f),
            surface = lerp(Color.White, accent, 0.03f),
            surfaceVariant = lerp(Color.White, accent, 0.10f),
            surfaceContainer = lerp(Color.White, accent, 0.06f),
        )
    }
    MaterialTheme(colorScheme = scheme, typography = picoTypography(), content = content)
}
