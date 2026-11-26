package com.picochat.app

import com.picochat.app.data.hf.HfService
import com.picochat.app.data.model.HfFileInfo
import com.picochat.app.data.model.formatBytes
import com.picochat.app.data.model.quantOf
import com.picochat.app.data.model.recommendedModels
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ModelsTest {
    @Test
    fun quantIsReadFromTheFileName() {
        assertEquals("Q4_K_M", quantOf("Qwen3-4B-Instruct-2507-Q4_K_M.gguf"))
        assertEquals("IQ3_XS", quantOf("model-IQ3_XS.gguf"))
        assertEquals("BF16", quantOf("model-bf16.gguf"))
        assertEquals("", quantOf("readme.gguf"))
    }

    @Test
    fun bytesAreFormatted() {
        assertEquals("0 B", formatBytes(0))
        assertEquals("2 KB", formatBytes(1536))
        assertEquals("2.5 GB", formatBytes((2.5 * 1024 * 1024 * 1024).toLong()))
    }

    @Test
    fun defaultFileIsQ4AndNeverTheProjector() {
        val files = listOf(
            HfFileInfo("m-Q8_0.gguf", 800),
            HfFileInfo("mmproj-F16.gguf", 50),
            HfFileInfo("m-Q4_K_M.gguf", 400),
        )
        assertEquals("m-Q4_K_M.gguf", HfService.pickDefault(files)?.name)
        assertEquals("m-Q8_0.gguf", HfService.pickDefault(files.filter { it.quant != "Q4_K_M" })?.name)
    }

    @Test
    fun recommendedListIsComplete() {
        assertEquals(9, recommendedModels.size)
        assertTrue(recommendedModels.all { it.repo.contains('/') && it.about.isNotEmpty() })
    }
}
