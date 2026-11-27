package com.picochat.app.domain

import com.picochat.app.data.store.MemoryStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.util.localDateTimeString

/**
 * Builds the system message. Only the parts that work today are included; the tool sections
 * (web search, files, cards, memory) come back with their features.
 */
object CorePrompt {
    private fun lengthRule(): String = when (Prefs.answerLength.value) {
        "short" -> "Keep answers very short: one or two sentences unless the user asks for more."
        "long" -> "Give thorough, well-structured answers with explanations and examples."
        "medium" -> "Keep answers clear and reasonably short; add detail only when it helps."
        else -> "Match the length of your answer to the question: brief for simple ones, more detail for complex ones."
    }

    fun build(): String {
        val date = localDateTimeString()
        val name = Prefs.userName.value.trim()
        return buildString {
            append(Prefs.systemPrompt.value.trim().ifEmpty { "You are Pico, a helpful assistant." })
            append("\n\n")
            append("Always reply in the language the user writes in. ")
            append("Use Markdown (short lists, **bold**, code blocks) only when it makes the answer easier to read. ")
            append(lengthRule())
            append("\nIf you do not know something, say so instead of inventing it.")
            append("\nCurrent date and time: ").append(date).append('.')
            if (name.isNotEmpty()) append("\nThe user's name is ").append(name).append('.')
            if (Prefs.memoryEnabled.value) {
                val facts = MemoryStore.recent(Prefs.memoryLimit.value)
                if (facts.isNotEmpty()) {
                    append("\n\nThings you remember about the user (use them naturally, never list them unless asked):")
                    facts.forEach { append("\n- ").append(it) }
                }
                append("\n\nWhen the user tells you a lasting personal fact (name, job, family, tastes, goals), ")
                append("end your reply with <remember>short fact in the user's language</remember>, one tag per fact. ")
                append("Never mention these tags and never save temporary details.")
            }
        }
    }
}
