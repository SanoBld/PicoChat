package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard
import kotlin.math.roundToInt

@Composable
fun ChatSettingsPage() {
    SectionCard(tr("ap_name")) {
        OutlinedTextField(
            value = Prefs.userName.value,
            onValueChange = { Prefs.userName.set(it) },
            label = { Text(tr("ap_name")) },
            placeholder = { Text(tr("ap_name_hint")) },
            singleLine = true,
            shape = MaterialTheme.shapes.large,
            modifier = Modifier.fillMaxWidth(),
        )
    }
    SectionCard(tr("cs_system_prompt")) {
        OutlinedTextField(
            value = Prefs.systemPrompt.value,
            onValueChange = { Prefs.systemPrompt.set(it) },
            minLines = 3,
            shape = MaterialTheme.shapes.large,
            modifier = Modifier.fillMaxWidth(),
        )
    }
    SectionCard(tr("cs_temperature")) {
        Text("${(Prefs.temperature.value * 10).roundToInt() / 10.0}", style = MaterialTheme.typography.titleLarge)
        Slider(
            value = Prefs.temperature.value.toFloat(),
            onValueChange = { Prefs.temperature.set((it * 10).roundToInt() / 10.0) },
            valueRange = 0f..1.5f,
        )
    }
    SectionCard(tr("cs_max_tokens")) {
        Text(tr("cs_max_tokens_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("${Prefs.maxTokens.value}", style = MaterialTheme.typography.titleLarge)
        Slider(
            value = Prefs.maxTokens.value.toFloat(),
            onValueChange = { Prefs.maxTokens.set(((it / 128).roundToInt() * 128).coerceAtLeast(128)) },
            valueRange = 128f..4096f,
        )
    }
    SectionCard(tr("set_context")) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(2048, 4096, 8192).forEach { n ->
                FilterChip(selected = Prefs.contextSize.value == n, onClick = { Prefs.contextSize.set(n) }, label = { Text("$n") })
            }
        }
    }
    SectionCard(tr("answer_len")) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("auto" to "len_auto", "short" to "len_short", "medium" to "len_medium", "long" to "len_long").forEach { (v, key) ->
                FilterChip(selected = Prefs.answerLength.value == v, onClick = { Prefs.answerLength.set(v) }, label = { Text(tr(key)) })
            }
        }
    }
    PicoButton(onClick = { Prefs.resetChatSettings() }, tonal = true) { Text(tr("cs_reset")) }
}
