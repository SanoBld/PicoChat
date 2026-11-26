package com.picochat.app.data.store

import com.picochat.app.data.model.AppJson
import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.Conversation
import com.picochat.app.util.Disk
import com.picochat.app.util.nowIso
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer

/** Conversations: kept in memory, saved to chats.json shortly after every change. */
object ChatStore {
    private val _chats = MutableStateFlow<List<Conversation>>(emptyList())
    val chats: StateFlow<List<Conversation>> = _chats

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var saveJob: Job? = null
    private val serializer = ListSerializer(Conversation.serializer())

    private fun file() = Disk.dir("data") + "/chats.json"

    fun load() {
        val txt = Disk.readText(file()) ?: return
        val list = runCatching { AppJson.decodeFromString(serializer, txt) }.getOrNull() ?: return
        _chats.value = list.sortedByDescending { it.updatedAt }
    }

    fun get(id: String): Conversation? = _chats.value.firstOrNull { it.id == id }

    fun create(modelId: String = ""): Conversation {
        val c = Conversation(modelId = modelId)
        _chats.value = listOf(c) + _chats.value
        scheduleSave()
        return c
    }

    fun update(id: String, touch: Boolean = true, change: (Conversation) -> Conversation) {
        _chats.value = _chats.value.map { c ->
            if (c.id != id) c else change(c).let { if (touch) it.copy(updatedAt = nowIso()) else it }
        }
        scheduleSave()
    }

    fun updateMessage(chatId: String, messageId: String, change: (ChatMessage) -> ChatMessage) {
        update(chatId, touch = false) { c -> c.copy(messages = c.messages.map { if (it.id == messageId) change(it) else it }) }
    }

    fun addMessages(chatId: String, vararg messages: ChatMessage) {
        update(chatId) { it.copy(messages = it.messages + messages) }
    }

    fun rename(id: String, title: String) = update(id, touch = false) { it.copy(title = title.trim(), autoTitle = false) }

    fun delete(id: String) {
        _chats.value = _chats.value.filterNot { it.id == id }
        scheduleSave()
    }

    fun clearAll() {
        _chats.value = emptyList()
        scheduleSave()
    }

    fun search(query: String): List<Conversation> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return _chats.value
        return _chats.value.filter { c -> c.title.lowercase().contains(q) || c.messages.any { it.text.lowercase().contains(q) } }
    }

    private fun scheduleSave() {
        saveJob?.cancel()
        saveJob = scope.launch {
            delay(500)
            flush()
        }
    }

    fun flush() {
        runCatching { Disk.writeAtomic(file(), AppJson.encodeToString(serializer, _chats.value)) }
    }
}
