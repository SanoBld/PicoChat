package com.picochat.app

import android.content.Intent
import android.speech.RecognitionService
import android.speech.SpeechRecognizer

/** Required by the assistant role. Real offline recognition comes with VoiceInput. */
class PicoRecognitionService : RecognitionService() {
    override fun onStartListening(recognizerIntent: Intent?, listener: Callback) = listener.error(SpeechRecognizer.ERROR_CLIENT)
    override fun onCancel(listener: Callback) = Unit
    override fun onStopListening(listener: Callback) = Unit
}
