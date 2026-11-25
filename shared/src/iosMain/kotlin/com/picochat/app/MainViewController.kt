package com.picochat.app

import androidx.compose.ui.window.ComposeUIViewController
import com.picochat.app.ui.App

/** Called from iosApp/ContentView.swift. */
@Suppress("FunctionNaming")
fun MainViewController() = ComposeUIViewController { App() }
