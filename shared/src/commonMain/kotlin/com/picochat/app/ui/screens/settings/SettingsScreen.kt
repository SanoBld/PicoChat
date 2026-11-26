package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.Strings
import com.picochat.app.l10n.supportedLocales
import com.picochat.app.l10n.tr
import com.picochat.app.ui.theme.accentChoices
import com.picochat.app.util.nativeInfo
import com.picochat.app.util.systemLanguage
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(showMenu: Boolean, onMenu: () -> Unit) {
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(tr("nav_settings")) },
            navigationIcon = { if (showMenu) IconButton(onClick = onMenu) { Icon(Icons.Default.Menu, contentDescription = null) } },
        )
    }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Section(tr("set_appearance")) {
                Label(tr("ap_theme"))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("system" to "ap_system", "light" to "ap_light", "dark" to "ap_dark").forEach { (v, key) ->
                        FilterChip(selected = Prefs.themeMode.value == v, onClick = { Prefs.themeMode.set(v) }, label = { Text(tr(key)) })
                    }
                }
                Label(tr("ap_accent"))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    accentChoices.forEach { (_, argb) ->
                        val selected = Prefs.accent.value == argb
                        Column(
                            Modifier.size(34.dp).clip(CircleShape).background(Color(argb)).clickable { Prefs.accent.set(argb) },
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) { if (selected) Text("✓", color = Color.White) }
                    }
                }
            }
            Section(tr("set_language")) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    supportedLocales.forEach { (code, name) ->
                        FilterChip(
                            selected = Prefs.locale.value == code,
                            onClick = {
                                Prefs.locale.set(code)
                                Strings.setLanguage(code)
                            },
                            label = { Text(name) },
                        )
                    }
                }
                Text(
                    "↺",
                    Modifier.clickable {
                        Prefs.locale.set("")
                        Strings.setLanguage(systemLanguage())
                    },
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            Section(tr("set_chat")) {
                OutlinedTextField(
                    value = Prefs.userName.value,
                    onValueChange = { Prefs.userName.set(it) },
                    label = { Text(tr("ap_name")) },
                    placeholder = { Text(tr("ap_name_hint")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = Prefs.systemPrompt.value,
                    onValueChange = { Prefs.systemPrompt.set(it) },
                    label = { Text(tr("cs_system_prompt")) },
                    minLines = 3,
                    modifier = Modifier.fillMaxWidth(),
                )
                Label("${tr("cs_temperature")}: ${((Prefs.temperature.value * 10).roundToInt() / 10.0)}")
                Slider(
                    value = Prefs.temperature.value.toFloat(),
                    onValueChange = { Prefs.temperature.set(((it * 10).roundToInt() / 10.0)) },
                    valueRange = 0f..1.5f,
                )
                Label("${tr("cs_max_tokens")}: ${Prefs.maxTokens.value}")
                Slider(
                    value = Prefs.maxTokens.value.toFloat(),
                    onValueChange = { Prefs.maxTokens.set(((it / 128).roundToInt() * 128).coerceAtLeast(128)) },
                    valueRange = 128f..4096f,
                )
                Label(tr("set_context"))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(2048, 4096, 8192).forEach { n ->
                        FilterChip(selected = Prefs.contextSize.value == n, onClick = { Prefs.contextSize.set(n) }, label = { Text("$n") })
                    }
                }
                Label(tr("answer_len"))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("short", "balanced", "detailed").forEach { v ->
                        FilterChip(selected = Prefs.answerLength.value == v, onClick = { Prefs.answerLength.set(v) }, label = { Text(v) })
                    }
                }
            }
            Section(tr("set_hf")) {
                OutlinedTextField(
                    value = Prefs.hfToken.value,
                    onValueChange = { Prefs.hfToken.set(it.trim()) },
                    label = { Text(tr("hf_token")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = Prefs.hfEndpoint.value,
                    onValueChange = { Prefs.hfEndpoint.set(it.trim()) },
                    label = { Text(tr("hf_endpoint")) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            Section(tr("engine_title")) {
                Text(nativeInfo().take(160), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(MaterialTheme.shapes.large).background(MaterialTheme.colorScheme.surfaceContainer).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
        content()
    }
}

@Composable
private fun Label(text: String) = Text(text, style = MaterialTheme.typography.labelLarge)
