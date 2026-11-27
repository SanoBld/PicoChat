package com.picochat.app.ui.screens.settings

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.runtime.getValue
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.SectionCard
import com.picochat.app.ui.components.SwitchRow
import com.picochat.app.ui.theme.PicoMotion
import com.picochat.app.ui.theme.accentChoices
import com.picochat.app.ui.theme.isDynamicColorSupported
import androidx.compose.material3.MaterialTheme

@Composable
fun AppearancePage() {
    SectionCard(tr("ap_theme")) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("system" to "ap_system", "light" to "ap_light", "dark" to "ap_dark").forEach { (v, key) ->
                FilterChip(selected = Prefs.themeMode.value == v, onClick = { Prefs.themeMode.set(v) }, label = { Text(tr(key)) })
            }
        }
    }
    val dynamicOn = isDynamicColorSupported() && Prefs.dynamicColor.value
    if (isDynamicColorSupported()) {
        SectionCard {
            SwitchRow(tr("ap_dynamic"), tr("ap_dynamic_sub"), Prefs.dynamicColor.value) { Prefs.dynamicColor.set(it) }
        }
    }
    if (!dynamicOn) {
        SectionCard(tr("ap_accent")) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                accentChoices.forEach { (_, argb) ->
                    val selected = Prefs.accent.value == argb
                    // the selected swatch grows with a spring
                    val size by animateDpAsState(if (selected) 42.dp else 34.dp, PicoMotion.spatial(), label = "swatch")
                    Box(
                        Modifier.size(size).clip(CircleShape).background(Color(argb)).clickable { Prefs.accent.set(argb) },
                        contentAlignment = Alignment.Center,
                    ) { if (selected) Text("✓", color = Color.White, style = MaterialTheme.typography.titleMedium) }
                }
            }
        }
    }
    SectionCard {
        SwitchRow(tr("ap_shapes"), tr("ap_shapes_sub"), Prefs.boxedAnswers.value) { Prefs.boxedAnswers.set(it) }
    }
}
