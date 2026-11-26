package com.picochat.app.domain

import com.picochat.app.data.store.Prefs
import com.picochat.app.util.localDateTimeString

/**
 * Builds the system message. Only the parts that work today are included; the tool sections
 * (web search, files, cards, memory) come back with their features.
 */
object CorePrompt {
    private fun lengthRule(): String = when (Prefs.answerLength.value) {
        "short" -> "Keep answers very short: one or two sentences unless the user asks for more."
        "detailed" -> "Give thorough, well-structured answers with explanations and examples."
        else -> "Keep answers clear and reasonably short; add detail only when it helps."
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
        }
    }
}
