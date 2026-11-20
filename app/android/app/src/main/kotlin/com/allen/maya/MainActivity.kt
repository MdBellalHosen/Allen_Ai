package com.allen.maya

import com.allen.maya.bridge.DeviceBridgePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceBridgePlugin.register(this, flutterEngine)
    }
}
