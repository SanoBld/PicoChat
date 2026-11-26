package com.picochat.app.util

import kotlin.random.Random

/** Short unique id (time + random), enough for local storage. */
fun newId(): String = nowMillis().toString(36) + Random.nextInt(0, 46656).toString(36)
