package com.picochat.app.data.model

import kotlinx.serialization.Serializable

private val quantRegex = Regex("(I?Q\\d(?:_[A-Z0-9]+)*|BF16|F16|F32)", RegexOption.IGNORE_CASE)

/** "model-Q4_K_M.gguf" -> "Q4_K_M" ("" if none). */
fun quantOf(fileName: String): String = quantRegex.findAll(fileName).lastOrNull()?.value?.uppercase() ?: ""

fun formatBytes(bytes: Long): String {
    if (bytes <= 0) return "0 B"
    val units = listOf("B", "KB", "MB", "GB", "TB")
    var v = bytes.toDouble()
    var i = 0
    while (v >= 1024 && i < units.lastIndex) {
        v /= 1024
        i++
    }
    val decimals = if (i >= 3) 1 else 0
    return "${roundTo(v, decimals)} ${units[i]}"
}

private fun roundTo(v: Double, decimals: Int): String {
    var factor = 1.0
    repeat(decimals) { factor *= 10 }
    val r = kotlin.math.round(v * factor) / factor
    return if (decimals == 0) r.toLong().toString() else r.toString()
}

/** A model file stored on the device. */
@Serializable
data class InstalledModel(
    /** "<repo>/<fileName>" or "local/<fileName>". */
    val id: String,
    val repo: String = "local",
    val fileName: String,
    val path: String,
    val sizeBytes: Long = 0,
    val addedAt: String = "",
) {
    val displayName: String
        get() = fileName.removeSuffix(".gguf").removeSuffix(".GGUF")
    val quant: String get() = quantOf(fileName)
}

/** A repo found on Hugging Face. */
data class HfModelSummary(
    val id: String,
    val downloads: Long,
    val likes: Long,
    val pipelineTag: String,
) {
    val author: String get() = id.substringBefore('/', "")
    val name: String get() = id.substringAfter('/')
}

/** One .gguf file of a repo. */
data class HfFileInfo(
    val name: String,
    val sizeBytes: Long,
) {
    val quant: String get() = quantOf(name)
    val isProjector: Boolean get() = name.contains("mmproj", ignoreCase = true)
}
