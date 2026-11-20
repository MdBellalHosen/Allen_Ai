package com.allen.allen_ai.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path

/** Coordinate gestures. Selectors (NodeFinder) are always preferred; this is the last resort. */
object GestureExecutor {
    fun tap(svc: AccessibilityService, x: Float, y: Float, done: (Boolean) -> Unit) =
        swipe(svc, x, y, x, y, 50, done)

    fun swipe(svc: AccessibilityService, x1: Float, y1: Float, x2: Float, y2: Float, durationMs: Long, done: (Boolean) -> Unit) {
        val path = Path().apply {
            moveTo(x1, y1)
            if (x1 != x2 || y1 != y2) lineTo(x2, y2)
        }
        val g = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(1)))
            .build()
        val ok = svc.dispatchGesture(g, object : AccessibilityService.GestureResultCallback() {
            override fun onCompleted(d: GestureDescription?) = done(true)
            override fun onCancelled(d: GestureDescription?) = done(false)
        }, null)
        if (!ok) done(false)
    }
}
