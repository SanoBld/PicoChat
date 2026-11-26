package com.picochat.app.util

import android.app.Application

/** Set once by PicoChatApp.onCreate. */
object AndroidContext {
    lateinit var app: Application
}

actual fun appDataDir(): String = AndroidContext.app.filesDir.absolutePath
