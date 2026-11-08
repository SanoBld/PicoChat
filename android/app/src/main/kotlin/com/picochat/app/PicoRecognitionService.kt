package com.picochat.app

import android.content.Intent
import android.speech.RecognitionService
import android.speech.SpeechRecognizer

// Android asks every assistant to declare a recognition service.
// This one does nothing: speech is handled inside the app (Whisper).
class PicoRecognitionService : RecognitionService() {
    override fun onStartListening(recognizerIntent: Intent?, listener: Callback?) {
        listener?.error(SpeechRecognizer.ERROR_CLIENT)
    }

    override fun onCancel(listener: Callback?) {}
    override fun onStopListening(listener: Callback?) {}
}
