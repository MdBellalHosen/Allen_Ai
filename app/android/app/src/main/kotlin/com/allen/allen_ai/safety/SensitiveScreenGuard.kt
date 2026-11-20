package com.allen.allen_ai.safety

import android.view.accessibility.AccessibilityNodeInfo

/**
 * Refuses to act on password / banking / payment screens (spec: user does these manually).
 * Heuristic and intentionally conservative. Add package keywords / phrases as needed.
 */
object SensitiveScreenGuard {
    private val packageKeywords = listOf(
        "bkash", "nagad", "upay", "rocket", "paisa", "paypal", "wallet", "banking", "bank",
        "authenticator", "passwordmanager", "lastpass", "bitwarden",
    )

    // Visible text that means "this screen asks for a secret".
    private val sensitivePhrases = listOf(
        "cvv", "card number", "enter pin", "enter your pin", "enter otp", "enter the otp", "one-time password",
        "verification code", "enter password", "পিন দিন", "ওটিপি", "কার্ড নম্বর", "পাসওয়ার্ড দিন", "পাসওয়ার্ড",
    )

    /** Returns a short reason code if the screen is sensitive, else null. */
    fun check(root: AccessibilityNodeInfo?): String? {
        if (root == null) return null
        val pkg = root.packageName?.toString()?.lowercase().orEmpty()
        if (packageKeywords.any { pkg.contains(it) }) return "payment_or_banking_app"
        return scan(root, 0)
    }

    private fun scan(n: AccessibilityNodeInfo, depth: Int): String? {
        if (depth > 40) return null
        if (n.isPassword) return "password_field"
        if (n.isVisibleToUser) {
            val label = ((n.text?.toString() ?: "") + " " + (n.contentDescription?.toString() ?: "")).lowercase()
            if (label.isNotBlank() && sensitivePhrases.any { label.contains(it) }) return "secret_requested"
        }
        for (i in 0 until n.childCount) {
            val c = n.getChild(i) ?: continue
            scan(c, depth + 1)?.let { return it }
        }
        return null
    }
}
