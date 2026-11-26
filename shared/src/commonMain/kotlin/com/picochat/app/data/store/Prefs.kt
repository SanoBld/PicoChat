package com.picochat.app.data.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.picochat.app.data.model.AppJson
import com.picochat.app.util.Disk
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive

/** One saved setting. Reading [value] inside a composable makes the UI follow changes. */
abstract class Pref<T>(val key: String, val default: T) {
    var value: T by mutableStateOf(default)
        private set

    internal abstract fun decode(e: JsonElement): T?
    internal abstract fun encode(v: T): JsonElement

    fun set(v: T) {
        value = v
        Prefs.put(key, encode(v))
    }

    internal fun loadFrom(m: Map<String, JsonElement>) {
        value = m[key]?.let { runCatching { decode(it) }.getOrNull() } ?: default
    }
}

class StringPref(key: String, default: String) : Pref<String>(key, default) {
    override fun decode(e: JsonElement) = e.jsonPrimitive.contentOrNull
    override fun encode(v: String): JsonElement = JsonPrimitive(v)
}

class BoolPref(key: String, default: Boolean) : Pref<Boolean>(key, default) {
    override fun decode(e: JsonElement) = e.jsonPrimitive.booleanOrNull
    override fun encode(v: Boolean): JsonElement = JsonPrimitive(v)
}

class IntPref(key: String, default: Int) : Pref<Int>(key, default) {
    override fun decode(e: JsonElement) = e.jsonPrimitive.intOrNull
    override fun encode(v: Int): JsonElement = JsonPrimitive(v)
}

class DoublePref(key: String, default: Double) : Pref<Double>(key, default) {
    override fun decode(e: JsonElement) = e.jsonPrimitive.doubleOrNull
    override fun encode(v: Double): JsonElement = JsonPrimitive(v)
}

const val DEFAULT_HF_ENDPOINT = "https://huggingface.co"
const val DEFAULT_SYSTEM_PROMPT =
    "You are Pico, the helpful, concise and friendly assistant of the PicoChat app, running entirely on the user's device."

/** All app settings, stored in prefs.json. Call [load] once at startup. */
object Prefs {
    private val all = mutableListOf<Pref<*>>()
    private var raw = mutableMapOf<String, JsonElement>()

    private fun <T : Pref<*>> reg(p: T): T {
        all += p
        return p
    }

    /** "system", "light" or "dark". */
    val themeMode = reg(StringPref("themeMode", "system"))
    val accent = reg(IntPref("accent", 0xFF0F766E.toInt()))
    /** Language code, "" = follow the system. */
    val locale = reg(StringPref("locale", ""))
    val userName = reg(StringPref("userName", ""))
    val systemPrompt = reg(StringPref("systemPrompt", DEFAULT_SYSTEM_PROMPT))
    val temperature = reg(DoublePref("temperature", 0.7))
    val maxTokens = reg(IntPref("maxTokens", 1024))
    val contextSize = reg(IntPref("contextSize", 4096))
    /** "short", "balanced" or "detailed". */
    val answerLength = reg(StringPref("answerLength", "balanced"))
    val autoTitle = reg(BoolPref("autoTitle", true))
    val activeModelId = reg(StringPref("activeModelId", ""))
    val hfEndpoint = reg(StringPref("hfEndpoint", DEFAULT_HF_ENDPOINT))
    val hfToken = reg(StringPref("hfToken", ""))

    private var loaded = false

    fun load() {
        if (loaded) return
        loaded = true
        Disk.readText(file())?.let { txt ->
            runCatching { AppJson.decodeFromString<Map<String, JsonElement>>(txt) }.getOrNull()?.let { raw = it.toMutableMap() }
        }
        all.forEach { it.loadFrom(raw) }
    }

    internal fun put(key: String, v: JsonElement) {
        raw[key] = v
        runCatching { Disk.writeAtomic(file(), AppJson.encodeToString(raw.toMap())) }
    }

    private fun file() = Disk.dir("data") + "/prefs.json"
}
