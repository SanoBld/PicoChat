package com.picochat.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession

// Called when the person triggers the assistant (power button hold, swipe, "Hey ...").
// It opens the small assistant card over the current app.
class PicoSession(context: Context) : VoiceInteractionSession(context) {
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        MainActivity.unloadModel()
        startAssistantActivity(Intent(context, AssistActivity::class.java))
        hide()
    }
}
