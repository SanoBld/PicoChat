package com.picochat.app

import android.app.Application
import com.picochat.app.util.AndroidContext

/** Process entry point: gives the shared code access to the app context. */
class PicoChatApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AndroidContext.app = this
    }
}
