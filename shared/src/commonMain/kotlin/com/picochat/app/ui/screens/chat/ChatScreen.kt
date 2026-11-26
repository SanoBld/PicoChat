package com.picochat.app.ui.screens.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isShiftPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.ChatRole
import com.picochat.app.data.store.ChatStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.domain.ChatService
import com.picochat.app.domain.ModelManager
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.MarkdownLite
import com.picochat.app.util.platformName

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    chatId: String?,
    showMenu: Boolean,
    onMenu: () -> Unit,
    onOpenModels: () -> Unit,
    onChatCreated: (String) -> Unit,
) {
    val chats by ChatStore.chats.collectAsState()
    val chat = chats.firstOrNull { it.id == chatId }
    val generatingId by ChatService.generatingChatId.collectAsState()
    val installed by ModelManager.installed.collectAsState()
    val active = installed.firstOrNull { it.id == Prefs.activeModelId.value }
    val generating = generatingId != null && generatingId == chat?.id
    val busy = generatingId != null
    var input by remember(chatId) { mutableStateOf("") }

    fun send() {
        val text = input.trim()
        if (text.isEmpty() || busy) return
        val id = chat?.id ?: ChatStore.create(active?.id ?: "").id.also(onChatCreated)
        input = ""
        ChatService.send(id, text)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(chat?.title?.ifBlank { null } ?: tr("new_chat"), maxLines = 1, style = MaterialTheme.typography.titleMedium)
                        Text(active?.displayName ?: "demo", style = MaterialTheme.typography.bodySmall, maxLines = 1)
                    }
                },
                navigationIcon = {
                    if (showMenu) IconButton(onClick = onMenu) { Icon(Icons.Default.Menu, contentDescription = null) }
                },
            )
        },
        bottomBar = {
            Row(
                Modifier.fillMaxWidth().padding(12.dp),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    modifier = Modifier.weight(1f).onPreviewKeyEvent { e ->
                        // desktop: Enter sends, Shift+Enter adds a line (phones keep the newline key)
                        if (platformName == "desktop" && e.key == Key.Enter && e.type == KeyEventType.KeyDown && !e.isShiftPressed) {
                            send()
                            true
                        } else {
                            false
                        }
                    },
                    placeholder = { Text(if (active == null) tr("no_model_hint") else tr("chat_hint")) },
                    maxLines = 6,
                    shape = RoundedCornerShape(24.dp),
                )
                if (generating) {
                    FilledIconButton(onClick = { ChatService.stop() }) { Icon(Icons.Default.Stop, contentDescription = tr("stop")) }
                } else {
                    FilledIconButton(onClick = { send() }, enabled = input.isNotBlank() && !busy) {
                        Icon(Icons.AutoMirrored.Filled.Send, contentDescription = tr("send"))
                    }
                }
            }
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (active == null) {
                DemoBanner(onOpenModels)
            }
            if (chat == null || chat.messages.isEmpty()) {
                EmptyState(onPick = { input = it })
            } else {
                MessageList(chat.messages, generating, onRegenerate = { ChatService.regenerate(chat) })
            }
        }
    }
}

@Composable
private fun DemoBanner(onOpenModels: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr("demo_banner"), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            TextButton(onClick = onOpenModels) { Text(tr("get_model")) }
        }
    }
}

@Composable
private fun EmptyState(onPick: (String) -> Unit) {
    val name = Prefs.userName.value.trim()
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            if (name.isEmpty()) tr("empty_title") else tr("empty_title_name", mapOf("name" to name)),
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center,
        )
        Text(
            tr("empty_sub"),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
}

@Composable
private fun MessageList(messages: List<ChatMessage>, generating: Boolean, onRegenerate: () -> Unit) {
    val state = rememberLazyListState()
    val lastLen = messages.lastOrNull()?.text?.length ?: 0
    LaunchedEffect(messages.size, lastLen) {
        if (messages.isNotEmpty()) state.scrollToItem(messages.lastIndex)
    }
    LazyColumn(state = state, modifier = Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)) {
        items(messages, key = { it.id }) { m ->
            val isLast = m.id == messages.last().id
            MessageItem(m, showActions = isLast && !generating && m.role == ChatRole.ASSISTANT, streaming = isLast && generating, onRegenerate = onRegenerate)
        }
    }
}

@Composable
private fun MessageItem(m: ChatMessage, showActions: Boolean, streaming: Boolean, onRegenerate: () -> Unit) {
    if (m.role == ChatRole.USER) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
            Text(
                m.text,
                Modifier.widthIn(max = 560.dp).background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(20.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
        return
    }
    Column(Modifier.fillMaxWidth().widthIn(max = 760.dp)) {
        if (m.text.isNotEmpty()) MarkdownLite(m.text)
        if (streaming && m.text.isEmpty()) Text("…", style = MaterialTheme.typography.titleLarge)
        if (m.failed) ErrorCard(m, onRetry = onRegenerate)
        if (m.stopped) Text(tr("stopped"), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (showActions) {
            val clipboard = LocalClipboardManager.current
            Row {
                IconButton(onClick = { clipboard.setText(AnnotatedString(m.text)) }) { Icon(Icons.Default.ContentCopy, contentDescription = tr("copy")) }
                IconButton(onClick = onRegenerate) { Icon(Icons.Default.Refresh, contentDescription = tr("regenerate")) }
            }
        }
    }
}

@Composable
private fun ErrorCard(m: ChatMessage, onRetry: () -> Unit) {
    val kind = m.errorKind.ifEmpty { "other" }
    var details by remember { mutableStateOf(false) }
    Card(
        Modifier.fillMaxWidth().padding(top = 6.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(tr("err_t_$kind"), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onErrorContainer)
            Text(tr("err_b_$kind"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onErrorContainer)
            if (m.error.isNotEmpty() && details) Text(m.error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
            Row {
                Button(onClick = onRetry) { Text(tr("retry")) }
                if (m.error.isNotEmpty()) TextButton(onClick = { details = !details }) { Text(if (details) tr("err_hide") else tr("err_details")) }
            }
        }
    }
}
