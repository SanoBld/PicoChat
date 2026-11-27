package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.data.store.MemoryStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard
import com.picochat.app.ui.components.SwitchRow

@Composable
fun MemoryPage() {
    val items by MemoryStore.items.collectAsState()
    var text by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf(false) }

    SectionCard {
        SwitchRow(tr("memory_enable"), tr("memory_enable_sub"), Prefs.memoryEnabled.value) { Prefs.memoryEnabled.set(it) }
    }
    SectionCard(tr("memory_add")) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                singleLine = true,
                shape = MaterialTheme.shapes.large,
                modifier = Modifier.weight(1f),
            )
            PicoButton(onClick = {
                if (MemoryStore.add(text)) text = ""
            }, enabled = text.isNotBlank(), icon = Icons.Default.Add) { Text(tr("memory_add")) }
        }
    }
    SectionCard(tr("mem_limit")) {
        Text(tr("mem_limit_sub"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(10, 25, 50, 0).forEach { n ->
                FilterChip(
                    selected = Prefs.memoryLimit.value == n,
                    onClick = { Prefs.memoryLimit.set(n) },
                    label = { Text(if (n == 0) tr("mem_all") else "$n") },
                )
            }
        }
    }
    SectionCard(tr("mem_section")) {
        if (items.isEmpty()) {
            Text(tr("memory_empty"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            items.forEach { m ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(m.text, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
                    IconButton(onClick = { MemoryStore.remove(m.id) }) { Icon(Icons.Default.Close, contentDescription = tr("delete")) }
                }
            }
            PicoButton(onClick = { confirm = true }, tonal = true) { Text(tr("memory_clear")) }
        }
    }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text(tr("memory_clear")) },
            confirmButton = { TextButton(onClick = { MemoryStore.clear(); confirm = false }) { Text(tr("delete")) } },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text(tr("cancel")) } },
        )
    }
}
