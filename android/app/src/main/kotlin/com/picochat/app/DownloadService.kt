package com.picochat.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

// Foreground service: keeps the app (and the model download) alive with the screen off,
// and shows the progress notification.
class DownloadService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = DownloadNotifier.progress(
            this,
            intent?.getStringExtra("title") ?: "PicoChat",
            intent?.getStringExtra("text") ?: "",
            intent?.getIntExtra("percent", -1) ?: -1
        )
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(DownloadNotifier.ID_PROGRESS, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(DownloadNotifier.ID_PROGRESS, n)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

object DownloadNotifier {
    const val ID_PROGRESS = 4001
    const val ID_DONE = 4002
    private const val CH_PROGRESS = "pc_download"
    private const val CH_DONE = "pc_download_done"

    private fun channels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CH_PROGRESS, "Downloads", NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel(CH_DONE, "Downloads finished", NotificationManager.IMPORTANCE_DEFAULT))
    }

    private fun open(ctx: Context) = android.app.PendingIntent.getActivity(
        ctx, 0, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
    )

    // percent: 0..100 = bar, -1 = unknown size (moving bar), -2 = no progress shown
    fun progress(ctx: Context, title: String, text: String, percent: Int): Notification {
        channels(ctx)
        val b = NotificationCompat.Builder(ctx, CH_PROGRESS)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(text)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setContentIntent(open(ctx))
        when {
            percent >= 0 -> b.setProgress(100, percent, false)
            percent == -1 -> b.setProgress(0, 0, true)
        }
        return b.build()
    }

    fun update(ctx: Context, title: String, text: String, percent: Int) {
        ctx.getSystemService(NotificationManager::class.java).notify(ID_PROGRESS, progress(ctx, title, text, percent))
    }

    fun done(ctx: Context, title: String, text: String) {
        channels(ctx)
        val n = NotificationCompat.Builder(ctx, CH_DONE)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setContentIntent(open(ctx))
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(ID_DONE, n)
    }
}
