package com.picochat.app.engine

import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.InstalledModel
import kotlinx.coroutines.flow.Flow

data class GenerationOptions(
    val temperature: Float = 0.7f,
    val maxTokens: Int = 1024,
)

/** The seam between the chat and whatever produces the answer (local llama.cpp, demo, cloud). */
interface InferenceEngine {
    val name: String
    /** True when answers are fake (no real engine available). */
    val isPlaceholder: Boolean
    val loadedModelId: String?

    suspend fun load(model: InstalledModel, contextSize: Int)

    /** Streams the answer piece by piece. [history] starts with the system message. */
    fun generate(history: List<ChatMessage>, options: GenerationOptions): Flow<String>

    /** Asks the running generation to end (the flow then completes normally). */
    fun stop()

    suspend fun unload()
}

/** Platform engine: llama.cpp on Android and desktop, the demo engine elsewhere. */
expect fun createEngine(): InferenceEngine
