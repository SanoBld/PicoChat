package com.picochat.app

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import com.picochat.app.ui.App

fun main() = application {
    Window(onCloseRequest = ::exitApplication, title = "PicoChat") { App() }
}
