package com.picochat.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.DateFormat
import java.util.Date

// Keeps the last notifications in memory (never written to disk) so the AI can answer
// "what are my notifications?". Only active when the person granted notification access.
class PicoNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val e = sbn.notification.extras
        val title = e.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = e.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        if (title.isBlank() && text.isBlank()) return
        val app = try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(sbn.packageName, 0)).toString()
        } catch (_: Exception) { sbn.packageName }
        val time = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(sbn.postTime))
        synchronized(items) {
            items.addFirst("$time — $app: $title ${text.take(200)}".trim())
            while (items.size > 30) items.removeLast()
        }
    }

    companion object {
        private val items = java.util.ArrayDeque<String>()
        fun recent(): List<String> = synchronized(items) { items.toList() }
    }
}
