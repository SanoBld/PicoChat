package com.picochat.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Flutter host. It tells the Dart side when Android opened the app as the assistant.
class MainActivity : FlutterActivity() {
    private var assist = false
    private var channel: MethodChannel? = null

    private fun isAssist(i: Intent?) =
        i?.action == Intent.ACTION_ASSIST || i?.getBooleanExtra("picochat_assist", false) == true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        assist = isAssist(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isAssist(intent)) {
            assist = true
            // The app is already running: tell Dart now.
            channel?.invokeMethod("assist", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "picochat/assist")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "consume") {
                result.success(assist)
                assist = false
            } else {
                result.notImplemented()
            }
        }
    }
}
