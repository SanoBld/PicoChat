package com.picochat.app.util

import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

actual fun nowMillis(): Long = System.currentTimeMillis()

actual fun localDateTimeString(): String = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))
