package com.picochat.app.domain

import com.picochat.app.data.store.ChatStore
import com.picochat.app.data.store.MemoryStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.Strings
import com.picochat.app.util.systemLanguage

/** Erase data: chats only, or the whole app. */
object ResetManager {
    fun eraseChats() {
        ChatService.stop()
        ChatStore.clearAll()
        ChatStore.flush()
    }

    /** Chats, memory, models and settings. The intro shows again afterwards. */
    fun resetAll() {
        ChatService.stop()
        ModelManager.deleteAll()
        ChatStore.clearAll()
        ChatStore.flush()
        MemoryStore.clear()
        Prefs.resetAll()
        Strings.setLanguage(systemLanguage())
    }
}
