package com.picochat.app

import android.content.Context
import android.content.Intent
import android.service.voice.VoiceInteractionSession

/** Assist session: opens the assistant card, then closes itself. */
class PicoSession(context: Context) : VoiceInteractionSession(context) {
    override fun onShow(args: android.os.Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        startAssistantActivity(Intent(context, AssistActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        hide()
    }
}
