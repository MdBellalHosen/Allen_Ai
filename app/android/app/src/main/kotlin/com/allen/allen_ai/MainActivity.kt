package com.allen.allen_ai

import com.allen.allen_ai.bridge.DeviceBridgePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceBridgePlugin.register(this, flutterEngine)
    }
}
