package com.picochat.app.ui.screens.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationDrawerItem
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.picochat.app.data.model.Conversation
import com.picochat.app.data.store.ChatStore
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton

@Composable
fun Sidebar(
    selectedChatId: String?,
    section: Section,
    onNewChat: () -> Unit,
    onOpenChat: (String) -> Unit,
    onOpenModels: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val chats by ChatStore.chats.collectAsState()
    var query by remember { mutableStateOf("") }
    var toDelete by remember { mutableStateOf<Conversation?>(null) }
    var toRename by remember { mutableStateOf<Conversation?>(null) }
    var renameText by remember { mutableStateOf("") }
    val shown = remember(chats, query) { ChatStore.search(query) }

    Column(modifier.fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("PicoChat", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(start = 8.dp, top = 4.dp))
        PicoButton(onClick = onNewChat, modifier = Modifier.fillMaxWidth(), tonal = true, icon = Icons.Default.Add) { Text(tr("new_chat")) }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text(tr("search_chats")) },
            singleLine = true,
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        LazyColumn(Modifier.weight(1f)) {
            items(shown, key = { it.id }) { c ->
                val selected = section == Section.CHAT && c.id == selectedChatId
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
                        .clickable { onOpenChat(c.id) }
                        .padding(start = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        c.title.ifBlank { tr("new_chat") },
                        Modifier.weight(1f).padding(vertical = 12.dp),
                        maxLines = 1,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    )
                    var menu by remember { mutableStateOf(false) }
                    Box {
                        IconButton(onClick = { menu = true }) { Icon(Icons.Default.MoreVert, contentDescription = null) }
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, shape = MaterialTheme.shapes.large) {
                            DropdownMenuItem(
                                text = { Text(tr("rename")) },
                                leadingIcon = { Icon(Icons.Default.Edit, contentDescription = null) },
                                onClick = { menu = false; toRename = c; renameText = c.title },
                            )
                            DropdownMenuItem(
                                text = { Text(tr("delete")) },
                                leadingIcon = { Icon(Icons.Default.Delete, contentDescription = null) },
                                onClick = { menu = false; toDelete = c },
                            )
                        }
                    }
                }
            }
        }
        NavigationDrawerItem(
            label = { Text(tr("nav_models")) },
            icon = { Icon(Icons.Default.Storage, contentDescription = null) },
            selected = section == Section.MODELS,
            onClick = onOpenModels,
        )
        NavigationDrawerItem(
            label = { Text(tr("nav_settings")) },
            icon = { Icon(Icons.Default.Settings, contentDescription = null) },
            selected = section == Section.SETTINGS,
            onClick = onOpenSettings,
        )
    }

    toRename?.let { c ->
        AlertDialog(
            onDismissRequest = { toRename = null },
            title = { Text(tr("rename")) },
            text = {
                OutlinedTextField(value = renameText, onValueChange = { renameText = it }, singleLine = true, modifier = Modifier.fillMaxWidth())
            },
            confirmButton = {
                TextButton(onClick = {
                    if (renameText.isNotBlank()) ChatStore.rename(c.id, renameText)
                    toRename = null
                }) { Text(tr("save")) }
            },
            dismissButton = { TextButton(onClick = { toRename = null }) { Text(tr("cancel")) } },
        )
    }
    toDelete?.let { c ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text(tr("delete_chat_q")) },
            text = { Text(tr("delete_chat_body")) },
            confirmButton = {
                TextButton(onClick = {
                    ChatStore.delete(c.id)
                    toDelete = null
                }) { Text(tr("delete")) }
            },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text(tr("cancel")) } },
        )
    }
}
