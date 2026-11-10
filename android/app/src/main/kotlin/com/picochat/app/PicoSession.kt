package com.picochat.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import java.io.File
import java.io.FileOutputStream

// Called when the person triggers the assistant (power button hold, swipe, "Hey ...").
// It opens the small assistant card over the current app.
class PicoSession(context: Context) : VoiceInteractionSession(context) {
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        AssistBridge.shotPath = null
        MainActivity.unloadModel()
        startAssistantActivity(Intent(context, AssistActivity::class.java))
        hide()
    }

    // The system gives a picture of the screen (if "Use screenshot" is on in Android settings).
    override fun onHandleScreenshot(screenshot: Bitmap?) {
        super.onHandleScreenshot(screenshot)
        if (screenshot == null) return
        // Never read the screen on the lock screen.
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (km.isKeyguardLocked) return
        try {
            val f = File(context.cacheDir, "assist_screen.jpg")
            FileOutputStream(f).use { screenshot.compress(Bitmap.CompressFormat.JPEG, 90, it) }
            AssistBridge.shotPath = f.absolutePath
            AssistBridge.onShot?.invoke(f.absolutePath)
        } catch (_: Exception) {
        }
    }
}
