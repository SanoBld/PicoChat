package com.picochat.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Transparent activity that shows the small assistant card (Dart: assistMain).
class AssistActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "assistMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "picochat/assist_overlay")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "close" -> {
                        finish()
                        result.success(null)
                    }
                    "openApp" -> {
                        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
