package com.picochat.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Flutter host. It can ask the Dart side to free the AI model (see PicoSession),
// reads phone data on request and runs the download foreground service.
class MainActivity : FlutterActivity() {
    companion object {
        private var channel: MethodChannel? = null

        // Called before the assistant overlay opens: it loads its own copy of the model.
        fun unloadModel() {
            channel?.invokeMethod("unload", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, "picochat/assist")
        DeviceBridge.register(this, messenger)

        MethodChannel(messenger, "picochat/download").setMethodCallHandler { call, result ->
            val title = call.argument<String>("title") ?: "PicoChat"
            val text = call.argument<String>("text") ?: ""
            val percent = call.argument<Int>("percent") ?: -1
            try {
                when (call.method) {
                    "start" -> {
                        val i = Intent(this, DownloadService::class.java)
                            .putExtra("title", title).putExtra("text", text).putExtra("percent", percent)
                        androidx.core.content.ContextCompat.startForegroundService(this, i)
                    }
                    "update" -> DownloadNotifier.update(this, title, text, percent)
                    "stop" -> stopService(Intent(this, DownloadService::class.java))
                    "done" -> DownloadNotifier.done(this, title, text)
                    else -> { result.notImplemented(); return@setMethodCallHandler }
                }
                result.success(null)
            } catch (e: Exception) {
                result.error("download", e.message, null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
