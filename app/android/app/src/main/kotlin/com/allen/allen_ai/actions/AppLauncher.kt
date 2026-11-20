package com.allen.allen_ai.actions

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.provider.Settings
import java.net.URLEncoder

/** Opens apps / URLs with Intents (faster and more reliable than tapping). */
class AppLauncher(private val ctx: Context) {
    // spoken name (English, Bangla, Banglish) -> package
    private val aliases: Map<String, String> = buildMap {
        fun add(pkg: String, vararg names: String) = names.forEach { put(it.lowercase(), pkg) }
        add("com.google.android.youtube", "youtube", "ইউটিউব", "ইউ টিউব", "you tube")
        add("com.facebook.katana", "facebook", "fb", "ফেসবুক", "ফেইসবুক")
        add("com.facebook.orca", "messenger", "মেসেঞ্জার")
        add("com.instagram.android", "instagram", "insta", "ইনস্টাগ্রাম", "ইন্সটাগ্রাম", "ইনস্টা")
        add("com.whatsapp", "whatsapp", "whats app", "হোয়াটসঅ্যাপ", "হোয়াটসএপ", "হোয়াটস অ্যাপ")
        add("com.android.chrome", "chrome", "ক্রোম")
        add("com.google.android.gm", "gmail", "জিমেইল")
        add("com.google.android.apps.maps", "maps", "google maps", "ম্যাপ", "ম্যাপস")
        add("com.spotify.music", "spotify", "স্পটিফাই")
        add("org.telegram.messenger", "telegram", "টেলিগ্রাম")
        add("com.zhiliaoapp.musically", "tiktok", "টিকটক")
        add("com.android.vending", "play store", "playstore", "প্লে স্টোর")
    }

    data class Result(val ok: Boolean, val message: String, val extra: Map<String, Any?> = emptyMap())

    private fun launch(intent: Intent): Boolean = try {
        // The accessibility service context is the most reliable way to start activities from the background.
        val c = com.allen.allen_ai.accessibility.AllenAccessibilityService.instance ?: ctx
        c.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    private fun norm(s: String) = s.trim().lowercase()

    fun resolvePackage(name: String): String? {
        val n = norm(name)
        aliases[n]?.let { return it }
        val pm = ctx.packageManager
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        var best: Pair<Int, String>? = null
        for (ri in pm.queryIntentActivities(main, 0)) {
            val label = norm(ri.loadLabel(pm).toString())
            val score = when {
                label == n -> 3
                label.startsWith(n) -> 2
                label.contains(n) -> 1
                else -> 0
            }
            if (score > 0 && (best == null || score > best.first)) best = score to ri.activityInfo.packageName
        }
        return best?.second
    }

    fun openApp(name: String): Result {
        val n = norm(name)
        when (n) {
            "settings", "সেটিংস", "setting" -> return Result(launch(Intent(Settings.ACTION_SETTINGS)), "settings")
            "camera", "ক্যামেরা" -> return Result(launch(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)), "camera")
        }
        val pkg = resolvePackage(n) ?: return Result(false, "app_not_found")
        val intent = ctx.packageManager.getLaunchIntentForPackage(pkg) ?: return Result(false, "app_not_launchable")
        return if (launch(intent)) Result(true, "opened", mapOf("package" to pkg)) else Result(false, "launch_blocked")
    }

    fun openUrl(url: String, pkg: String? = null): Result {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        if (pkg != null) i.setPackage(pkg)
        return if (launch(i)) Result(true, "opened") else Result(false, "launch_blocked")
    }

    /** Phase 3 supports YouTube and Google search via URLs. Other apps arrive with the LLM agent. */
    fun searchInApp(app: String, query: String): Result {
        val q = URLEncoder.encode(query, "UTF-8")
        return when (norm(app)) {
            "youtube", "ইউটিউব" -> {
                val url = "https://www.youtube.com/results?search_query=$q"
                val pkg = "com.google.android.youtube"
                val inApp = openUrl(url, pkg)
                if (inApp.ok) inApp else openUrl(url) // no YouTube app -> browser
            }
            "google", "chrome", "web", "গুগল" -> openUrl("https://www.google.com/search?q=$q")
            else -> Result(false, "search_not_supported_for_app")
        }
    }
}
