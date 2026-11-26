package com.picochat.app.engine

import com.picochat.app.data.model.ChatMessage
import com.picochat.app.data.model.ChatRole
import com.picochat.app.data.model.InstalledModel
import com.picochat.llama.LlamaBridge
import com.picochat.llama.TokenCallback
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Local engine: llama.cpp through the JNI bridge. One model at a time. */
class LlamaEngine : InferenceEngine {
    override val name = "llama.cpp"
    override val isPlaceholder = false
    override var loadedModelId: String? = null
        private set

    private var handle = 0L
    private var loadedContext = 0

    @Volatile
    private var stopRequested = false

    override suspend fun load(model: InstalledModel, contextSize: Int) = withContext(Dispatchers.IO) {
        if (handle != 0L && loadedModelId == model.id && loadedContext == contextSize) return@withContext
        freeNow()
        check(LlamaBridge.isAvailable) { "Native engine not available: ${LlamaBridge.loadError}" }
        handle = LlamaBridge.nativeLoad(model.path.encodeToByteArray(), contextSize, 0)
        loadedModelId = model.id
        loadedContext = contextSize
    }

    override fun generate(history: List<ChatMessage>, options: GenerationOptions): Flow<String> = channelFlow {
        val h = handle
        check(h != 0L) { "No model loaded" }
        stopRequested = false
        val roles = history.map { if (it.role == ChatRole.SYSTEM) "system" else if (it.role == ChatRole.USER) "user" else "assistant" }
            .toTypedArray()
        val contents = history.map { it.text.encodeToByteArray() }.toTypedArray()
        val job = launch(Dispatchers.IO) {
            LlamaBridge.nativeGenerate(h, roles, contents, options.temperature, options.maxTokens, TokenCallback { bytes ->
                // trySend fails once the collector is gone: that also stops the native loop
                trySend(bytes.decodeToString()).isSuccess && !stopRequested
            })
        }
        job.join()
    }

    override fun stop() {
        stopRequested = true
        if (handle != 0L) LlamaBridge.nativeStop(handle)
    }

    override suspend fun unload() = withContext(Dispatchers.IO) { freeNow() }

    private fun freeNow() {
        if (handle != 0L) LlamaBridge.nativeFree(handle)
        handle = 0L
        loadedModelId = null
    }
}
