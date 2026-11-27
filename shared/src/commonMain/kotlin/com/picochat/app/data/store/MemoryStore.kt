package com.picochat.app.data.store

import com.picochat.app.data.model.AppJson
import com.picochat.app.util.Disk
import com.picochat.app.util.newId
import com.picochat.app.util.nowIso
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

@Serializable
data class MemoryItem(
    val id: String = newId(),
    val text: String,
    val createdAt: String = nowIso(),
)

/** Long-term facts the assistant remembers about the user (memory.json). */
object MemoryStore {
    private const val MAX_ITEMS = 300
    private val _items = MutableStateFlow<List<MemoryItem>>(emptyList())
    /** Newest first. */
    val items: StateFlow<List<MemoryItem>> = _items
    private val serializer = ListSerializer(MemoryItem.serializer())

    private fun file() = Disk.dir("data") + "/memory.json"

    fun load() {
        val txt = Disk.readText(file()) ?: return
        _items.value = runCatching { AppJson.decodeFromString(serializer, txt) }.getOrNull().orEmpty()
    }

    /** Returns false when the fact is empty or already known. */
    fun add(text: String): Boolean {
        val t = text.trim().trimEnd('.').trim()
        if (t.length < 3 || _items.value.any { it.text.equals(t, ignoreCase = true) }) return false
        _items.value = (listOf(MemoryItem(text = t)) + _items.value).take(MAX_ITEMS)
        save()
        return true
    }

    fun remove(id: String) {
        _items.value = _items.value.filterNot { it.id == id }
        save()
    }

    fun clear() {
        _items.value = emptyList()
        save()
    }

    /** The memories sent to the model, most recent first. [limit] 0 = all. */
    fun recent(limit: Int): List<String> = _items.value.let { if (limit > 0) it.take(limit) else it }.map { it.text }

    private fun save() {
        runCatching { Disk.writeAtomic(file(), AppJson.encodeToString(serializer, _items.value)) }
    }
}
