package com.example.sos

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.sos/emergency"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "showEmergencyScreen") {
                val message = call.argument<String>("message")
                val intent = Intent(this, EmergencyAlertActivity::class.java).apply {
                    putExtra("message", message)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("trigger_sos", false)) {
            // إخبار Flutter بإرسال النداء عند الضغط على أزرار الصوت
            methodChannel?.invokeMethod("triggerSOS", null)
        }
    }
}
