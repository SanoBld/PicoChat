package com.picochat.app.data.hf

import com.picochat.app.data.model.AppJson
import com.picochat.app.data.model.HfFileInfo
import com.picochat.app.data.model.HfModelSummary
import com.picochat.app.data.store.DEFAULT_HF_ENDPOINT
import com.picochat.app.data.store.Prefs
import com.picochat.app.util.Http
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.encodeURLParameter
import io.ktor.http.encodeURLPath
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

/** [kind] is one of: auth, rateLimit, notFound, server, network, parse, other (matches the err_* strings). */
class HfException(val kind: String, val status: Int = 0, message: String = kind) : Exception(message)

object HfService {
    fun endpoint(): String = Prefs.hfEndpoint.value.trim().trimEnd('/').ifEmpty { DEFAULT_HF_ENDPOINT }

    /** Download URL of a file (the server redirects to a CDN). */
    fun resolveUrl(repo: String, file: String): String = "${endpoint()}/$repo/resolve/main/${file.encodeURLPath()}"

    fun authHeader(): String? = Prefs.hfToken.value.trim().takeIf { it.isNotEmpty() }?.let { "Bearer $it" }

    private suspend fun getJson(url: String): JsonElement {
        val resp = try {
            Http.api.get(url) { authHeader()?.let { header(HttpHeaders.Authorization, it) } }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw HfException("network", 0, e.message ?: "network")
        }
        val code = resp.status.value
        when {
            code == 401 || code == 403 -> throw HfException("auth", code)
            code == 404 -> throw HfException("notFound", code)
            code == 429 -> throw HfException("rateLimit", code)
            code in 500..599 -> throw HfException("server", code)
            code !in 200..299 -> throw HfException("other", code)
        }
        return try {
            AppJson.parseToJsonElement(resp.bodyAsText())
        } catch (e: Exception) {
            throw HfException("parse", code, e.message ?: "parse")
        }
    }

    /** GGUF repos, most downloaded first. Empty query = popular models. */
    suspend fun search(query: String, limit: Int = 30): List<HfModelSummary> {
        val q = if (query.isBlank()) "" else "&search=${query.trim().encodeURLParameter()}"
        val json = getJson("${endpoint()}/api/models?filter=gguf&sort=downloads&direction=-1&limit=$limit$q")
        return (json as? JsonArray ?: throw HfException("parse")).mapNotNull { e ->
            val o = e as? JsonObject ?: return@mapNotNull null
            val id = o["id"]?.jsonPrimitive?.contentOrNull ?: o["modelId"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
            HfModelSummary(
                id = id,
                downloads = o["downloads"]?.jsonPrimitive?.longOrNull ?: 0L,
                likes = o["likes"]?.jsonPrimitive?.longOrNull ?: 0L,
                pipelineTag = o["pipeline_tag"]?.jsonPrimitive?.contentOrNull ?: "",
            )
        }
    }

    /** All .gguf files of a repo, smallest first. */
    suspend fun listFiles(repo: String): List<HfFileInfo> {
        val json = getJson("${endpoint()}/api/models/$repo/tree/main?recursive=true")
        val files = (json as? JsonArray ?: throw HfException("parse")).mapNotNull { e ->
            val o = e as? JsonObject ?: return@mapNotNull null
            if (o["type"]?.jsonPrimitive?.contentOrNull != "file") return@mapNotNull null
            val path = o["path"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
            if (!path.endsWith(".gguf", ignoreCase = true)) return@mapNotNull null
            val size = (o["lfs"] as? JsonObject)?.get("size")?.jsonPrimitive?.longOrNull ?: o["size"]?.jsonPrimitive?.longOrNull ?: 0L
            HfFileInfo(path, size)
        }
        return files.sortedBy { it.sizeBytes }
    }

    private val preferredQuants = listOf("Q4_K_M", "Q4_K_S", "Q4_0", "Q5_K_M", "Q5_K_S", "Q4_1", "Q6_K", "Q3_K_M", "Q8_0")

    /** The file to download by default: a Q4 quantisation, never the vision projector. */
    fun pickDefault(files: List<HfFileInfo>): HfFileInfo? {
        val models = files.filterNot { it.isProjector }
        for (q in preferredQuants) models.firstOrNull { it.quant == q }?.let { return it }
        return models.minByOrNull { it.sizeBytes }
    }
}
