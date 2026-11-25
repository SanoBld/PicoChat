package com.picochat.app.l10n

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.picochat.app.resources.Res
import kotlinx.serialization.json.Json

/** Translation tables (composeResources/files/strings_xx.json). Missing key -> English -> the key itself. */
object Strings {
    private val codes = listOf("en", "fr", "es", "de")
    private var tables: Map<String, Map<String, String>> = emptyMap()

    /** Current language code. Reading it in a composable makes the UI follow language changes. */
    var lang by mutableStateOf("en")
        private set

    suspend fun load() {
        tables = codes.associateWith { c ->
            Json.decodeFromString<Map<String, String>>(Res.readBytes("files/strings_$c.json").decodeToString())
        }
    }

    fun setLanguage(code: String) {
        lang = if (code in codes) code else "en"
    }

    fun tr(key: String, args: Map<String, String>? = null): String {
        var s = tables[lang]?.get(key) ?: tables["en"]?.get(key) ?: key
        args?.forEach { (k, v) -> s = s.replace("{$k}", v) }
        return s
    }
}

/** Short form used everywhere in the UI: tr("key") or tr("key", mapOf("name" to x)). */
fun tr(key: String, args: Map<String, String>? = null): String = Strings.tr(key, args)
