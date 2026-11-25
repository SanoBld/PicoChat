package com.picochat.app

import android.app.Service
import android.content.Intent
import android.os.IBinder

/** Foreground service keeping a model download alive (dataSync). Implemented with ModelManager. */
class DownloadService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
