package com.picochat.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Flutter host. It can ask the Dart side to free the AI model (see PicoSession).
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
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "picochat/assist")
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
