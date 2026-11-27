package com.picochat.app.ui.screens.chat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
import com.picochat.app.ui.theme.AnswerBoxShape
import com.picochat.app.ui.theme.PicoMotion
import com.picochat.app.ui.theme.UserBubbleShape
import com.picochat.app.util.platformName
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.longOrNull

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

    fun send(text: String = input) {
        val t = text.trim()
        if (t.isEmpty() || busy) return
        val id = chat?.id ?: ChatStore.create(active?.id ?: "").id.also(onChatCreated)
        input = ""
        ChatService.send(id, t)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.surface,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(chat?.title?.ifBlank { null } ?: tr("new_chat"), maxLines = 1, style = MaterialTheme.typography.titleMedium)
                        Text(
                            active?.displayName ?: "demo",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                        )
                    }
                },
                navigationIcon = { if (showMenu) IconButton(onClick = onMenu) { Icon(Icons.Default.Menu, contentDescription = null) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface),
            )
        },
        bottomBar = {
            Composer(
                value = input,
                onValueChange = { input = it },
                hint = if (active == null) tr("no_model_hint") else tr("chat_hint"),
                generating = generating,
                canSend = input.isNotBlank() && !busy,
                onSend = { send() },
                onStop = { ChatService.stop() },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (active == null) DemoBanner(onOpenModels)
            if (chat == null || chat.messages.isEmpty()) {
                EmptyState(onPick = { send(it) })
            } else {
                MessageList(chat.messages, generating, onRegenerate = { ChatService.regenerate(chat) })
            }
        }
    }
}

/** Rounded input container; the send button becomes a stop button (and changes shape) while answering. */
@Composable
private fun Composer(
    value: String,
    onValueChange: (String) -> Unit,
    hint: String,
    generating: Boolean,
    canSend: Boolean,
    onSend: () -> Unit,
    onStop: () -> Unit,
) {
    val corner by animateDpAsState(if (generating) 14.dp else 28.dp, PicoMotion.spatial(), label = "sendShape")
    Surface(
        modifier = Modifier.fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = 12.dp, vertical = 8.dp),
        shape = MaterialTheme.shapes.extraLarge,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
    ) {
        Row(Modifier.padding(start = 4.dp, end = 8.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.Bottom) {
            TextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f).onPreviewKeyEvent { e ->
                    // desktop: Enter sends, Shift+Enter adds a line (phones keep the newline key)
                    if (platformName == "desktop" && e.key == Key.Enter && e.type == KeyEventType.KeyDown && !e.isShiftPressed) {
                        onSend()
                        true
                    } else {
                        false
                    }
                },
                placeholder = { Text(hint) },
                maxLines = 6,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    disabledIndicatorColor = Color.Transparent,
                ),
            )
            FilledIconButton(
                onClick = if (generating) onStop else onSend,
                enabled = generating || canSend,
                shape = RoundedCornerShape(corner),
                modifier = Modifier.padding(bottom = 4.dp).size(48.dp),
            ) {
                Icon(
                    if (generating) Icons.Default.Stop else Icons.AutoMirrored.Filled.Send,
                    contentDescription = if (generating) tr("stop") else tr("send"),
                )
            }
        }
    }
}

@Composable
private fun DemoBanner(onOpenModels: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer),
    ) {
        Row(Modifier.padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tr("demo_banner"), Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onTertiaryContainer)
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
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
        )
        Column(Modifier.widthIn(max = 520.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("suggest_1", "suggest_2", "suggest_3", "suggest_4").forEach { key ->
                val text = tr(key)
                Surface(
                    onClick = { onPick(text) },
                    shape = MaterialTheme.shapes.large,
                    color = MaterialTheme.colorScheme.surfaceContainerHigh,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text, Modifier.padding(horizontal = 18.dp, vertical = 14.dp), style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
    }
}

@Composable
private fun MessageList(messages: List<ChatMessage>, generating: Boolean, onRegenerate: () -> Unit) {
    val state = rememberLazyListState()
    val lastLen = messages.lastOrNull()?.text?.length ?: 0
    LaunchedEffect(messages.size, lastLen) {
        if (messages.isNotEmpty()) state.scrollToItem(messages.lastIndex)
    }
    LazyColumn(
        state = state,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        items(messages, key = { it.id }) { m ->
            val isLast = m.id == messages.last().id
            Box(Modifier.animateItem()) {
                MessageItem(
                    m,
                    showActions = isLast && !generating && m.role == ChatRole.ASSISTANT,
                    streaming = isLast && generating,
                    onRegenerate = onRegenerate,
                )
            }
        }
    }
}

@Composable
private fun MessageItem(m: ChatMessage, showActions: Boolean, streaming: Boolean, onRegenerate: () -> Unit) {
    if (m.role == ChatRole.USER) {
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
            Text(
                m.text,
                Modifier.widthIn(max = 560.dp).clip(UserBubbleShape).background(MaterialTheme.colorScheme.primaryContainer)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
        }
        return
    }
    val boxed = Prefs.boxedAnswers.value
    Column(
        Modifier.fillMaxWidth().widthIn(max = 760.dp).then(
            if (boxed) Modifier.clip(AnswerBoxShape).background(MaterialTheme.colorScheme.surfaceContainerLow).padding(16.dp) else Modifier,
        ),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (m.text.isNotEmpty()) MarkdownLite(m.text)
        if (streaming && m.text.isEmpty()) TypingDots()
        if (m.failed) ErrorCard(m, onRetry = onRegenerate)
        if (m.memories.isNotEmpty()) {
            AssistChip(
                onClick = {},
                label = { Text(tr("memory_saved")) },
                leadingIcon = { Icon(Icons.Default.Psychology, contentDescription = null, Modifier.size(18.dp)) },
                shape = MaterialTheme.shapes.large,
            )
        }
        if (m.stopped) Text(tr("stopped"), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (showActions) {
            val clipboard = LocalClipboardManager.current
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { clipboard.setText(AnnotatedString(m.text)) }) { Icon(Icons.Default.ContentCopy, contentDescription = tr("copy")) }
                IconButton(onClick = onRegenerate) { Icon(Icons.Default.Refresh, contentDescription = tr("regenerate")) }
                speedLabel(m)?.let {
                    Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 4.dp))
                }
            }
        }
    }
}

/** "12 tok/s" computed from the answer stats, or null while unknown. */
private fun speedLabel(m: ChatMessage): String? {
    val pieces = (m.stats["pieces"] as? JsonPrimitive)?.longOrNull ?: return null
    val ms = (m.stats["ms"] as? JsonPrimitive)?.longOrNull ?: return null
    if (pieces < 3 || ms <= 0) return null
    return tr("chat_tps", mapOf("n" to (pieces * 1000 / ms).toString()))
}

@Composable
private fun TypingDots() {
    val transition = rememberInfiniteTransition(label = "dots")
    Row(Modifier.padding(vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(3) { i ->
            val a by transition.animateFloat(
                initialValue = 0.25f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(tween(600, delayMillis = i * 160), RepeatMode.Reverse),
                label = "dot$i",
            )
            Box(Modifier.size(10.dp).alpha(a).clip(CircleShape).background(MaterialTheme.colorScheme.primary))
        }
    }
}

@Composable
private fun ErrorCard(m: ChatMessage, onRetry: () -> Unit) {
    val kind = m.errorKind.ifEmpty { "other" }
    var details by remember { mutableStateOf(false) }
    Card(
        Modifier.fillMaxWidth().padding(top = 6.dp),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(tr("err_t_$kind"), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onErrorContainer)
            Text(tr("err_b_$kind"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onErrorContainer)
            if (m.error.isNotEmpty() && details) Text(m.error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onErrorContainer)
            Row {
                TextButton(onClick = onRetry) { Text(tr("retry")) }
                if (m.error.isNotEmpty()) TextButton(onClick = { details = !details }) { Text(if (details) tr("err_hide") else tr("err_details")) }
            }
        }
    }
}
