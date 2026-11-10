package com.picochat.app

// Shares the screenshot (given by the system to the assistant) with the assistant card.
object AssistBridge {
    @Volatile var shotPath: String? = null
    @Volatile var onShot: ((String) -> Unit)? = null
}
