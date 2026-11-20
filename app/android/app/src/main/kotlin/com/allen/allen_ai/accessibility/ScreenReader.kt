package com.allen.allen_ai.accessibility

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo

/** Builds a compact, LLM-friendly description of the visible screen. Never returns password text. */
object ScreenReader {
    private const val MAX_NODES = 150

    fun read(root: AccessibilityNodeInfo?): Map<String, Any?> {
        val nodes = ArrayList<Map<String, Any?>>()
        if (root != null) walk(root, nodes, 0)
        return mapOf("package" to root?.packageName?.toString(), "nodes" to nodes)
    }

    private fun walk(n: AccessibilityNodeInfo, out: MutableList<Map<String, Any?>>, depth: Int) {
        if (out.size >= MAX_NODES || depth > 40) return
        if (n.isVisibleToUser) {
            val text = if (n.isPassword) null else n.text?.toString()?.take(120)
            val desc = n.contentDescription?.toString()?.take(120)
            if (!text.isNullOrBlank() || !desc.isNullOrBlank() || n.isClickable || n.isEditable) {
                val r = Rect().also { n.getBoundsInScreen(it) }
                out.add(
                    mapOf(
                        "id" to n.viewIdResourceName?.substringAfter(":id/"),
                        "text" to text,
                        "desc" to desc,
                        "cls" to n.className?.toString()?.substringAfterLast('.'),
                        "click" to n.isClickable,
                        "edit" to n.isEditable,
                        "scroll" to n.isScrollable,
                        "bounds" to listOf(r.left, r.top, r.right, r.bottom),
                    )
                )
            }
        }
        for (i in 0 until n.childCount) {
            val c = n.getChild(i) ?: continue
            walk(c, out, depth + 1)
        }
    }
}
