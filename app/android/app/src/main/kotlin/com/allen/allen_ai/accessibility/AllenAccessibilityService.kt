package com.allen.allen_ai.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Entry point for controlling other apps. We do not react to events; we only expose
 * [instance] so the bridge can read the active window and perform actions on demand.
 */
class AllenAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* on-demand only */ }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    companion object {
        @Volatile
        var instance: AllenAccessibilityService? = null
        val isRunning: Boolean get() = instance != null
    }
}
