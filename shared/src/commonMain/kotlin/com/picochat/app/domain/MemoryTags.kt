package com.picochat.app.domain

/** The model saves a fact by ending its answer with <remember>fact</remember>. */
object MemoryTags {
    private const val OPEN = "<remember>"
    private val full = Regex("<remember>(.*?)</remember>", setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE))

    /** Text without the tags, plus the facts found in them. */
    fun extract(text: String): Pair<String, List<String>> {
        val facts = full.findAll(text).map { it.groupValues[1].trim() }.filter { it.length in 3..300 }.toList()
        return hide(text) to facts
    }

    /** Removes complete tags and an unfinished one at the end (while the answer is streaming). */
    fun hide(text: String): String {
        var s = full.replace(text, "")
        val open = s.lastIndexOf(OPEN, ignoreCase = true)
        if (open >= 0) {
            s = s.substring(0, open)
        } else {
            val lt = s.lastIndexOf('<')
            if (lt >= 0 && OPEN.startsWith(s.substring(lt).lowercase())) s = s.substring(0, lt)
        }
        return s.trimEnd()
    }
}
