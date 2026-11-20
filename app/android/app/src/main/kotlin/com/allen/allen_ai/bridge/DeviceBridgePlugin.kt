package com.allen.allen_ai.bridge

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import com.allen.allen_ai.accessibility.AllenAccessibilityService
import com.allen.allen_ai.accessibility.GestureExecutor
import com.allen.allen_ai.accessibility.NodeFinder
import com.allen.allen_ai.accessibility.ScreenReader
import com.allen.allen_ai.actions.AppLauncher
import com.allen.allen_ai.actions.MediaController
import com.allen.allen_ai.actions.SystemSettings
import com.allen.allen_ai.safety.SensitiveScreenGuard
import com.allen.allen_ai.service.AllenForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Single MethodChannel entry point for all device tools.
 * Every reply is a map: {ok: Boolean, message: String, data: Map?} so Dart never handles exceptions.
 */
object DeviceBridgePlugin {
    const val CHANNEL = "allen/device"
    private val main = Handler(Looper.getMainLooper())

    private fun ok(message: String = "ok", data: Map<String, Any?>? = null) =
        mapOf("ok" to true, "message" to message, "data" to data)

    private fun fail(message: String) = mapOf("ok" to false, "message" to message, "data" to null)

    fun register(context: Context, engine: FlutterEngine) {
        val app = context.applicationContext
        val launcher = AppLauncher(app)
        val media = MediaController(app)
        val sys = SystemSettings(app)

        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        // Kill switch (volume-down x3 from the accessibility service) -> Dart
        AllenAccessibilityService.killListener = { main.post { channel.invokeMethod("killSwitch", null) } }

        channel.setMethodCallHandler { call, result ->
            try {
                handle(app, call, result, launcher, media, sys)
            } catch (e: Exception) {
                result.success(fail("exception:${e.javaClass.simpleName}"))
            }
        }
    }

    private fun svc(): AllenAccessibilityService? = AllenAccessibilityService.instance

    private fun isAccessibilityEnabled(ctx: Context): Boolean {
        if (AllenAccessibilityService.isRunning) return true
        val enabled = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(ctx, AllenAccessibilityService::class.java).flattenToString()
        return enabled.split(':').any { it.equals(me, ignoreCase = true) }
    }

    private fun handle(
        ctx: Context, call: MethodCall, result: MethodChannel.Result,
        launcher: AppLauncher, media: MediaController, sys: SystemSettings,
    ) {
        when (call.method) {
            "startForegroundService" -> {
                ContextCompat.startForegroundService(ctx, Intent(ctx, AllenForegroundService::class.java))
                result.success(ok())
            }
            "stopForegroundService" -> {
                ctx.stopService(Intent(ctx, AllenForegroundService::class.java))
                result.success(ok())
            }

            "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled(ctx))
            "openAccessibilitySettings" -> {
                ctx.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(ok())
            }

            // ---- no accessibility needed ----
            "openApp" -> {
                val r = launcher.openApp(call.argument<String>("name").orEmpty())
                result.success(if (r.ok) ok(r.message, r.extra) else fail(r.message))
            }
            "openUrl" -> {
                val r = launcher.openUrl(call.argument<String>("url").orEmpty())
                result.success(if (r.ok) ok(r.message) else fail(r.message))
            }
            "searchInApp" -> {
                val r = launcher.searchInApp(call.argument<String>("app").orEmpty(), call.argument<String>("query").orEmpty())
                result.success(if (r.ok) ok(r.message) else fail(r.message))
            }
            "mediaControl" ->
                result.success(if (media.control(call.argument<String>("action").orEmpty())) ok() else fail("unknown_media_action"))
            "setVolume" -> {
                val pct = media.volume(call.argument<String>("direction"), call.argument<Int>("level"))
                result.success(ok("volume", mapOf("percent" to pct)))
            }
            "toggleSetting" -> {
                val name = call.argument<String>("name").orEmpty()
                if (name == "flashlight" || name == "torch") {
                    val r = sys.torch(call.argument<Boolean>("on"))
                    result.success(
                        r.fold({ ok("torch", mapOf("on" to it)) }, { fail("torch_failed:${it.message}") })
                    )
                } else {
                    val opened = sys.openPanel(name)
                    // Honest result: the panel is opened, the user flips the switch (Android restriction).
                    result.success(if (opened) ok("panel_opened", mapOf("toggled" to false)) else fail("unknown_setting"))
                }
            }

            // ---- accessibility needed ----
            "pressGlobal", "readScreen", "tap", "typeText", "scroll", "swipe" -> {
                val s = svc()
                if (s == null) {
                    result.success(fail("accessibility_off"))
                    return
                }
                handleAccessibility(s, call, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleAccessibility(s: AllenAccessibilityService, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pressGlobal" -> {
                val action = when (call.argument<String>("action")) {
                    "back" -> AccessibilityService.GLOBAL_ACTION_BACK
                    "home" -> AccessibilityService.GLOBAL_ACTION_HOME
                    "recents" -> AccessibilityService.GLOBAL_ACTION_RECENTS
                    "notifications" -> AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS
                    "quick_settings" -> AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS
                    else -> { result.success(fail("unknown_global_action")); return }
                }
                result.success(if (s.performGlobalAction(action)) ok() else fail("global_action_failed"))
            }

            "readScreen" -> {
                val root = s.rootInActiveWindow
                val reason = SensitiveScreenGuard.check(root)
                result.success(if (reason != null) fail("sensitive_screen:$reason") else ok("screen", ScreenReader.read(root)))
            }

            "tap" -> {
                val match = call.argument<List<String>>("match")
                val clickableOnly = call.argument<Boolean>("clickableOnly") ?: false
                val timeout = (call.argument<Int>("timeoutMs") ?: 0).toLong()
                if (match != null) {
                    pollTap(s, match, clickableOnly, timeout, System.currentTimeMillis(), result)
                } else {
                    val x = call.argument<Double>("x")
                    val y = call.argument<Double>("y")
                    if (x == null || y == null) { result.success(fail("tap_needs_match_or_xy")); return }
                    val reason = SensitiveScreenGuard.check(s.rootInActiveWindow)
                    if (reason != null) { result.success(fail("sensitive_screen:$reason")); return }
                    GestureExecutor.tap(s, x.toFloat(), y.toFloat()) { done ->
                        result.success(if (done) ok() else fail("gesture_failed"))
                    }
                }
            }

            "typeText" -> {
                val root = s.rootInActiveWindow
                val reason = SensitiveScreenGuard.check(root)
                if (reason != null) { result.success(fail("sensitive_screen:$reason")); return }
                val field = NodeFinder.editable(root)
                if (field == null) { result.success(fail("no_text_field")); return }
                val done = NodeFinder.setText(field, call.argument<String>("text").orEmpty())
                result.success(if (done) ok() else fail("set_text_failed"))
            }

            "scroll" -> {
                val down = call.argument<String>("direction") != "up"
                val root = s.rootInActiveWindow
                val reason = SensitiveScreenGuard.check(root)
                if (reason != null) { result.success(fail("sensitive_screen:$reason")); return }
                val node = NodeFinder.scrollable(root)
                val action = if (down) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                if (node != null && node.performAction(action)) {
                    result.success(ok())
                } else {
                    // Fallback: swipe the middle of the screen.
                    val m = s.resources.displayMetrics
                    val x = m.widthPixels / 2f
                    val (y1, y2) = if (down) (m.heightPixels * 0.7f to m.heightPixels * 0.3f) else (m.heightPixels * 0.3f to m.heightPixels * 0.7f)
                    GestureExecutor.swipe(s, x, y1, x, y2, 300) { done -> result.success(if (done) ok() else fail("gesture_failed")) }
                }
            }

            "swipe" -> {
                fun d(k: String) = call.argument<Double>(k)?.toFloat() ?: 0f
                GestureExecutor.swipe(s, d("x1"), d("y1"), d("x2"), d("y2"), (call.argument<Int>("durationMs") ?: 300).toLong()) { done ->
                    result.success(if (done) ok() else fail("gesture_failed"))
                }
            }
        }
    }

    /** Looks for a matching node, retrying every 300 ms until [timeout] (screens load asynchronously). */
    private fun pollTap(
        s: AllenAccessibilityService, match: List<String>, clickableOnly: Boolean,
        timeout: Long, start: Long, result: MethodChannel.Result,
    ) {
        val root = s.rootInActiveWindow
        val reason = SensitiveScreenGuard.check(root)
        if (reason != null) { result.success(fail("sensitive_screen:$reason")); return }
        val node = NodeFinder.find(root, match, clickableOnly)
        if (node != null) {
            result.success(if (NodeFinder.click(node)) ok() else fail("click_failed"))
        } else if (System.currentTimeMillis() - start < timeout) {
            main.postDelayed({ pollTap(s, match, clickableOnly, timeout, start, result) }, 300)
        } else {
            result.success(fail("node_not_found"))
        }
    }
}
