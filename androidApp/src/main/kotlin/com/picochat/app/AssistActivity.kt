package com.picochat.app

import android.os.Bundle
import androidx.activity.ComponentActivity

/** Small assistant card opened by the system assist gesture (AssistOverlay in phase 2). */
class AssistActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        finish()
    }
}
