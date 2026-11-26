package com.picochat.app.data.model

import com.picochat.app.util.newId
import com.picochat.app.util.nowIso
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/** JSON settings shared by every store: same field names as the Flutter app, tolerant when reading. */
val AppJson = Json {
    ignoreUnknownKeys = true
    encodeDefaults = false
    coerceInputValues = true
    isLenient = true
}

@Serializable
enum class ChatRole {
    @SerialName("system") SYSTEM,
    @SerialName("user") USER,
    @SerialName("assistant") ASSISTANT,
}

@Serializable
data class ChatMessage(
    val id: String = newId(),
    val role: ChatRole,
    val text: String = "",
    val createdAt: String = nowIso(),
    val stopped: Boolean = false,
    val failed: Boolean = false,
    val error: String = "",
    val errorKind: String = "",
    val context: String = "",
    val files: List<String> = emptyList(),
    val sources: List<JsonObject> = emptyList(),
    val memories: List<String> = emptyList(),
    val cards: List<JsonObject> = emptyList(),
    val steps: List<JsonObject> = emptyList(),
    val stats: JsonObject = JsonObject(emptyMap()),
    /** Image paths of this turn: kept in memory only. */
    @Transient val images: List<String> = emptyList(),
)

@Serializable
data class Conversation(
    val id: String = newId(),
    val title: String = "",
    val autoTitle: Boolean = true,
    val createdAt: String = nowIso(),
    val updatedAt: String = nowIso(),
    val modelId: String = "",
    val messages: List<ChatMessage> = emptyList(),
)
