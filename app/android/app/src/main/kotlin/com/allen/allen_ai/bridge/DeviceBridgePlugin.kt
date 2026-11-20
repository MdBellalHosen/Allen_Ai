package com.allen.allen_ai.bridge

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.allen.allen_ai.service.AllenForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Single MethodChannel entry point. Phase 3 adds the device tools (tap, scroll, open_app...). */
object DeviceBridgePlugin {
    const val CHANNEL = "allen/device"

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    ContextCompat.startForegroundService(context, Intent(context, AllenForegroundService::class.java))
                    result.success(null)
                }
                "stopForegroundService" -> {
                    context.stopService(Intent(context, AllenForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
