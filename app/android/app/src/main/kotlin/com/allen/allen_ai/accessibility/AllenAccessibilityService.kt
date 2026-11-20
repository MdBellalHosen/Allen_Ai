package com.allen.allen_ai.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/**
 * Entry point for controlling other apps. We do not react to events; we only expose
 * [instance] so the bridge can read the active window and perform actions on demand.
 * Kill switch: pressing volume-down three times within 1.5 s calls [killListener].
 */
class AllenAccessibilityService : AccessibilityService() {
    private val volumeDownTimes = ArrayDeque<Long>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* on-demand only */ }

    override fun onInterrupt() {}

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event != null && event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0
        ) {
            val now = SystemClock.uptimeMillis()
            volumeDownTimes.addLast(now)
            while (volumeDownTimes.isNotEmpty() && now - volumeDownTimes.first() > 1500) volumeDownTimes.removeFirst()
            if (volumeDownTimes.size >= 3) {
                volumeDownTimes.clear()
                killListener?.invoke()
            }
        }
        return false // never swallow the key: volume still changes normally
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    companion object {
        @Volatile
        var instance: AllenAccessibilityService? = null
        val isRunning: Boolean get() = instance != null

        @Volatile
        var killListener: (() -> Unit)? = null
    }
}
