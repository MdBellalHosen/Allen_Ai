package com.allen.maya.bridge

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.allen.maya.service.MayaForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Single MethodChannel entry point. Phase 3 adds the device tools (tap, scroll, open_app...). */
object DeviceBridgePlugin {
    const val CHANNEL = "maya/device"

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    ContextCompat.startForegroundService(context, Intent(context, MayaForegroundService::class.java))
                    result.success(null)
                }
                "stopForegroundService" -> {
                    context.stopService(Intent(context, MayaForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
