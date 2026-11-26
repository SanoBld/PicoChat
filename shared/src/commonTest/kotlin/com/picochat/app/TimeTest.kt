package com.picochat.app

import com.picochat.app.util.isoFromMillis
import kotlin.test.Test
import kotlin.test.assertEquals

class TimeTest {
    @Test
    fun isoMatchesKnownInstants() {
        assertEquals("1970-01-01T00:00:00.000Z", isoFromMillis(0))
        assertEquals("2026-01-01T00:00:00.123Z", isoFromMillis(1767225600123))
        assertEquals("2000-02-29T00:00:00.000Z", isoFromMillis(951782400000))
    }
}
