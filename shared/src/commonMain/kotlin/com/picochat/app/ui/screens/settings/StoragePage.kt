package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.picochat.app.data.model.formatBytes
import com.picochat.app.data.store.ChatStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.domain.ModelManager
import com.picochat.app.domain.ResetManager
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard

private enum class Confirm { CHATS, APPEARANCE, ALL }

@Composable
fun StoragePage() {
    val installed by ModelManager.installed.collectAsState()
    val chats by ChatStore.chats.collectAsState()
    var confirm by remember { mutableStateOf<Confirm?>(null) }
    var typed by remember { mutableStateOf("") }

    SectionCard(tr("set_storage")) {
        Text("${installed.size} · ${formatBytes(installed.sumOf { it.sizeBytes })}", style = MaterialTheme.typography.titleLarge)
        Text(tr("set_storage_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    SectionCard(tr("st_clear_partials")) {
        Text(tr("st_clear_partials_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        PicoButton(onClick = { ModelManager.clearPartials() }, tonal = true) { Text(tr("st_clear_partials")) }
    }
    SectionCard(tr("st_clear_chats")) {
        Text("${chats.size}", style = MaterialTheme.typography.titleLarge)
        PicoButton(onClick = { confirm = Confirm.CHATS }, tonal = true, enabled = chats.isNotEmpty()) { Text(tr("st_clear_chats")) }
    }
    SectionCard(tr("reset_appearance")) {
        Text(tr("reset_appearance_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        PicoButton(onClick = { confirm = Confirm.APPEARANCE }, tonal = true) { Text(tr("reset_appearance")) }
    }
    SectionCard(tr("reset_all")) {
        Text(tr("reset_all_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        PicoButton(onClick = { typed = ""; confirm = Confirm.ALL }) { Text(tr("reset_all")) }
    }

    confirm?.let { c ->
        val body = when (c) {
            Confirm.CHATS -> tr("st_clear_chats_q")
            Confirm.APPEARANCE -> tr("reset_settings_body")
            Confirm.ALL -> tr("reset_all_1") + "\n\n" + tr("reset_all_2")
        }
        val ready = c != Confirm.ALL || typed == "RESET"
        AlertDialog(
            onDismissRequest = { confirm = null },
            title = { Text(when (c) { Confirm.CHATS -> tr("st_clear_chats"); Confirm.APPEARANCE -> tr("reset_appearance"); Confirm.ALL -> tr("reset_all") }) },
            text = {
                androidx.compose.foundation.layout.Column {
                    Text(body)
                    if (c == Confirm.ALL) {
                        Text(tr("reset_all_3"), style = MaterialTheme.typography.labelLarge)
                        OutlinedTextField(value = typed, onValueChange = { typed = it }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    }
                }
            },
            confirmButton = {
                TextButton(enabled = ready, onClick = {
                    when (c) {
                        Confirm.CHATS -> ResetManager.eraseChats()
                        Confirm.APPEARANCE -> Prefs.resetAppearance()
                        Confirm.ALL -> ResetManager.resetAll()
                    }
                    confirm = null
                }) { Text(tr("delete")) }
            },
            dismissButton = { TextButton(onClick = { confirm = null }) { Text(tr("cancel")) } },
        )
    }
}
