package com.picochat.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.text.DateFormat
import java.util.Date

// Read-only access to contacts, SMS, notifications and calendar.
// The Dart side only calls this when the person enabled the source AND granted the permission.
object DeviceBridge {
    fun register(ctx: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "picochat/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "contacts" -> result.success(contacts(ctx, call.argument<List<String>>("tokens") ?: emptyList()))
                    "sms" -> result.success(sms(ctx, call.argument<Int>("limit") ?: 10))
                    "calendar" -> result.success(calendar(ctx, call.argument<Int>("days") ?: 14))
                    "notifications" -> result.success(PicoNotificationListener.recent())
                    "granted" -> result.success(
                        androidx.core.content.ContextCompat.checkSelfPermission(ctx, call.argument<String>("p") ?: "") ==
                            android.content.pm.PackageManager.PERMISSION_GRANTED
                    )
                    "notifAccess" -> result.success(
                        NotificationManagerCompat.getEnabledListenerPackages(ctx).contains(ctx.packageName)
                    )
                    "openNotifAccess" -> {
                        ctx.startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("device", e.message, null)
            }
        }
    }

    private fun contacts(ctx: Context, tokens: List<String>): List<String> {
        val out = mutableListOf<String>()
        val cr = ctx.contentResolver
        val cols = arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER)
        cr.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI, cols, null, null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )?.use { c ->
            while (c.moveToNext() && out.size < 15) {
                val name = c.getString(0) ?: continue
                val num = c.getString(1) ?: ""
                val ok = tokens.isEmpty() || tokens.any { name.contains(it, ignoreCase = true) }
                val line = "$name: $num"
                if (ok && !out.contains(line)) out.add(line)
            }
        }
        return out
    }

    private fun sms(ctx: Context, limit: Int): List<String> {
        val out = mutableListOf<String>()
        val fmt = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
        ctx.contentResolver.query(
            Uri.parse("content://sms/inbox"), arrayOf("address", "body", "date"), null, null, "date DESC"
        )?.use { c ->
            while (c.moveToNext() && out.size < limit) {
                out.add("${fmt.format(Date(c.getLong(2)))} — ${c.getString(0)}: ${(c.getString(1) ?: "").take(300)}")
            }
        }
        return out
    }

    private fun calendar(ctx: Context, days: Int): List<String> {
        val out = mutableListOf<String>()
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0); set(java.util.Calendar.MINUTE, 0); set(java.util.Calendar.SECOND, 0)
        }
        val now = cal.timeInMillis // start of today: earlier events of today count
        val end = now + days * 86_400_000L
        val fmt = DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            android.content.ContentUris.appendId(it, now)
            android.content.ContentUris.appendId(it, end)
        }.build()
        ctx.contentResolver.query(
            uri, arrayOf(CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN, CalendarContract.Instances.EVENT_LOCATION),
            null, null, CalendarContract.Instances.BEGIN + " ASC"
        )?.use { c ->
            while (c.moveToNext() && out.size < 25) {
                val loc = c.getString(2)?.takeIf { it.isNotBlank() }?.let { " ($it)" } ?: ""
                out.add("${fmt.format(Date(c.getLong(1)))} — ${c.getString(0) ?: ""}$loc")
            }
        }
        return out
    }
}
