package com.allen.allen_ai.accessibility

import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo

/** Fuzzy, case-insensitive node lookup that works for Bangla and English labels. */
object NodeFinder {
    private fun norm(s: String?) = s?.trim()?.lowercase().orEmpty()

    /** 3 = exact, 2 = starts with, 1 = contains, 0 = no match. */
    private fun score(candidate: String?, q: String): Int {
        val c = norm(candidate)
        if (c.isEmpty()) return 0
        return when {
            c == q -> 3
            c.startsWith(q) -> 2
            c.contains(q) -> 1
            else -> 0
        }
    }

    /** Best node whose text / contentDescription / view id matches any of [queries]. */
    fun find(root: AccessibilityNodeInfo?, queries: List<String>, clickableOnly: Boolean = false): AccessibilityNodeInfo? {
        if (root == null) return null
        val qs = queries.map { norm(it) }.filter { it.isNotEmpty() }
        var best: AccessibilityNodeInfo? = null
        var bestScore = 0
        fun walk(n: AccessibilityNodeInfo, depth: Int) {
            if (depth > 40) return
            if (n.isVisibleToUser && !n.isPassword) {
                val s = qs.maxOfOrNull {
                    maxOf(score(n.text?.toString(), it), score(n.contentDescription?.toString(), it), score(n.viewIdResourceName, it))
                } ?: 0
                // strict ">" keeps the first (top-most / earliest) node among equal scores
                if (s > bestScore && (!clickableOnly || clickTarget(n) != null)) {
                    best = n
                    bestScore = s
                }
            }
            for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1) }
        }
        walk(root, 0)
        return best
    }

    /** The node itself or its closest clickable ancestor. */
    fun clickTarget(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var cur: AccessibilityNodeInfo? = n
        var hops = 0
        while (cur != null && hops < 8) {
            if (cur.isClickable) return cur
            cur = cur.parent
            hops++
        }
        return null
    }

    fun click(n: AccessibilityNodeInfo): Boolean = clickTarget(n)?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false

    fun editable(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)?.let { if (it.isEditable) return it }
        var found: AccessibilityNodeInfo? = null
        fun walk(n: AccessibilityNodeInfo, depth: Int) {
            if (found != null || depth > 40) return
            if (n.isEditable && n.isVisibleToUser) { found = n; return }
            for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1) }
        }
        walk(root, 0)
        return found
    }

    fun setText(n: AccessibilityNodeInfo, text: String): Boolean {
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return n.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun scrollable(root: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (root == null) return null
        var found: AccessibilityNodeInfo? = null
        fun walk(n: AccessibilityNodeInfo, depth: Int) {
            if (found != null || depth > 40) return
            if (n.isScrollable && n.isVisibleToUser) { found = n; return }
            for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1) }
        }
        walk(root, 0)
        return found
    }
}
