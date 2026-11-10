package com.picochat.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Transparent activity that shows the small assistant card (Dart: assistMain).
// It also works on the lock screen. Animations are drawn by Flutter (no system animation).
class AssistActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "assistMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        // Show over the lock screen.
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        AssistBridge.onShot = null
        super.onDestroy()
    }

    private fun locked(): Boolean =
        (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

    private fun openMain() {
        startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "picochat/assist_overlay")
        channel = ch
        // A screenshot that arrives after the card is open.
        AssistBridge.onShot = { path -> runOnUiThread { ch.invokeMethod("screenshot", path) } }
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "close" -> {
                    finish()
                    result.success(null)
                }
                "locked" -> result.success(locked())
                "screenshot" -> result.success(if (locked()) null else AssistBridge.shotPath)
                "openApp" -> {
                    if (locked() && Build.VERSION.SDK_INT >= 26) {
                        // Ask for the PIN / fingerprint, then open the app.
                        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        km.requestDismissKeyguard(this as Activity, object : KeyguardManager.KeyguardDismissCallback() {
                            override fun onDismissSucceeded() = openMain()
                        })
                    } else {
                        openMain()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
