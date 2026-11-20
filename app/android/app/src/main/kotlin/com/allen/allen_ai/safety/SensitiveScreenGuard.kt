package com.allen.allen_ai.safety

import android.view.accessibility.AccessibilityNodeInfo

/**
 * Refuses to act on password / banking / payment screens (spec: user does these manually).
 * Heuristic and intentionally conservative; Phase 4 extends it. Add package keywords as needed.
 */
object SensitiveScreenGuard {
    private val packageKeywords = listOf(
        "bkash", "nagad", "upay", "rocket", "paisa", "paypal", "wallet", "banking", "bank",
        "authenticator", "passwordmanager", "lastpass", "bitwarden",
    )

    /** Returns a short reason code if the screen is sensitive, else null. */
    fun check(root: AccessibilityNodeInfo?): String? {
        if (root == null) return null
        val pkg = root.packageName?.toString()?.lowercase().orEmpty()
        if (packageKeywords.any { pkg.contains(it) }) return "payment_or_banking_app"
        return if (hasPasswordField(root, 0)) "password_field" else null
    }

    private fun hasPasswordField(n: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 40) return false
        if (n.isPassword) return true
        for (i in 0 until n.childCount) {
            val c = n.getChild(i) ?: continue
            if (hasPasswordField(c, depth + 1)) return true
        }
        return false
    }
}
