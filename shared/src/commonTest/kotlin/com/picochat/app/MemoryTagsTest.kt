package com.picochat.app

import com.picochat.app.domain.MemoryTags
import kotlin.test.Test
import kotlin.test.assertEquals

class MemoryTagsTest {
    @Test
    fun factsAreExtractedAndHidden() {
        val (text, facts) = MemoryTags.extract("Nice to meet you!\n<remember>The user is called Sam</remember>")
        assertEquals("Nice to meet you!", text)
        assertEquals(listOf("The user is called Sam"), facts)
    }

    @Test
    fun unfinishedTagIsHiddenWhileStreaming() {
        assertEquals("Hello", MemoryTags.hide("Hello <remember>The user li"))
        assertEquals("Hello", MemoryTags.hide("Hello <rem"))
        assertEquals("a < b", MemoryTags.hide("a < b"))
    }

    @Test
    fun severalFacts() {
        val (_, facts) = MemoryTags.extract("Ok <remember>likes tea</remember> <remember>lives in Lyon</remember>")
        assertEquals(listOf("likes tea", "lives in Lyon"), facts)
    }
}
