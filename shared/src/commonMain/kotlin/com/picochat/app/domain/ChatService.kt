package com.picochat.app.domain

import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.ChatRole
import com.picochat.app.data.model.Conversation
import com.picochat.app.data.model.InstalledModel
import com.picochat.app.data.store.ChatStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.engine.GenerationOptions
import com.picochat.app.engine.InferenceEngine
import com.picochat.app.engine.PlaceholderEngine
import com.picochat.app.engine.createEngine
import com.picochat.app.util.nowMillis
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Sends a message and streams the answer into the conversation. One answer at a time. */
object ChatService {
    private val localEngine: InferenceEngine by lazy { createEngine() }
    private val demoEngine = PlaceholderEngine()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var job: Job? = null
    private var currentEngine: InferenceEngine = demoEngine
    private var userStopped = false

    private val _generatingChatId = MutableStateFlow<String?>(null)
    /** Id of the conversation being answered, or null. */
    val generatingChatId: StateFlow<String?> = _generatingChatId

    /** True when answers are fake because no model is installed. */
    fun isDemo(): Boolean = ModelManager.activeModel() == null || localEngine.isPlaceholder

    fun send(chatId: String, text: String) {
        val clean = text.trim()
        if (clean.isEmpty() || _generatingChatId.value != null) return
        val conv = ChatStore.get(chatId) ?: return
        val active = ModelManager.activeModel()

        val user = ChatMessage(role = ChatRole.USER, text = clean)
        val answer = ChatMessage(role = ChatRole.ASSISTANT)
        ChatStore.update(chatId) {
            it.copy(
                messages = it.messages + user + answer,
                modelId = active?.id ?: it.modelId,
                title = if (it.title.isBlank() && Prefs.autoTitle.value) clean.take(40).trim() else it.title,
            )
        }
        val history = historyFor(conv.messages + user)

        _generatingChatId.value = chatId
        userStopped = false
        job = scope.launch { generate(chatId, answer.id, history, active) }
    }

    fun stop() {
        userStopped = true
        currentEngine.stop()
    }

    private suspend fun generate(chatId: String, answerId: String, history: List<ChatMessage>, active: InstalledModel?) {
        val started = nowMillis()
        val text = StringBuilder()
        var pieces = 0
        try {
            val engine = if (active == null || localEngine.isPlaceholder) demoEngine else localEngine
            currentEngine = engine
            if (engine !== demoEngine && active != null) engine.load(active, Prefs.contextSize.value)
            val opts = GenerationOptions(Prefs.temperature.value.toFloat(), Prefs.maxTokens.value)
            var lastUi = 0L
            engine.generate(history, opts).collect { piece ->
                text.append(piece)
                pieces++
                val now = nowMillis()
                if (now - lastUi >= 70) {
                    lastUi = now
                    val snapshot = text.toString()
                    ChatStore.updateMessage(chatId, answerId) { it.copy(text = snapshot) }
                }
            }
            finishAnswer(chatId, answerId, text.toString(), started, pieces, failedKind = if (text.isBlank() && !userStopped) "empty" else "")
        } catch (e: CancellationException) {
            finishAnswer(chatId, answerId, text.toString(), started, pieces, failedKind = "")
            throw e
        } catch (e: Exception) {
            finishAnswer(chatId, answerId, text.toString(), started, pieces, failedKind = "local", error = e.message ?: "")
        } finally {
            _generatingChatId.value = null
        }
    }

    private fun finishAnswer(chatId: String, answerId: String, text: String, startedMs: Long, pieces: Int, failedKind: String, error: String = "") {
        val ms = nowMillis() - startedMs
        ChatStore.updateMessage(chatId, answerId) {
            it.copy(
                text = text,
                stopped = userStopped,
                failed = failedKind.isNotEmpty(),
                errorKind = failedKind,
                error = error,
                stats = buildJsonObject {
                    put("pieces", pieces)
                    put("ms", ms)
                },
            )
        }
        ChatStore.flush()
    }

    /** System prompt + as much recent history as fits in the context window. */
    private fun historyFor(messages: List<ChatMessage>): List<ChatMessage> {
        val budgetChars = ((Prefs.contextSize.value - Prefs.maxTokens.value).coerceAtLeast(512)) * 3
        val kept = ArrayDeque<ChatMessage>()
        var used = 0
        for (m in messages.reversed()) {
            if (m.role == ChatRole.SYSTEM || (m.failed && m.text.isBlank())) continue
            used += m.text.length + 12
            if (used > budgetChars && kept.isNotEmpty()) break
            kept.addFirst(m)
        }
        return listOf(ChatMessage(role = ChatRole.SYSTEM, text = CorePrompt.build())) + kept
    }

    fun regenerate(chat: Conversation) {
        val lastUser = chat.messages.lastOrNull { it.role == ChatRole.USER } ?: return
        ChatStore.update(chat.id) { c ->
            val idx = c.messages.indexOfLast { it.id == lastUser.id }
            c.copy(messages = c.messages.take(idx))
        }
        send(chat.id, lastUser.text)
    }
}
