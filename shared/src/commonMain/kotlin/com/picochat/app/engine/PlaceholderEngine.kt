package com.picochat.app.engine

import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.InstalledModel
import com.picochat.app.l10n.tr
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/** Demo engine used when no model is installed: streams a fixed text word by word. */
class PlaceholderEngine : InferenceEngine {
    override val name = "demo"
    override val isPlaceholder = true
    override val loadedModelId: String? = null
    private var stopped = false

    override suspend fun load(model: InstalledModel, contextSize: Int) = Unit

    override fun generate(history: List<ChatMessage>, options: GenerationOptions): Flow<String> = flow {
        stopped = false
        for (word in tr("demo_reply").split(" ")) {
            if (stopped) break
            emit("$word ")
            delay(35)
        }
    }

    override fun stop() {
        stopped = true
    }

    override suspend fun unload() = Unit
}
