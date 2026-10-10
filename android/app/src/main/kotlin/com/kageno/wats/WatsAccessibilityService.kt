package com.kageno.wats

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class WatsAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "WatsA11y"

        @Volatile
        var instance: WatsAccessibilityService? = null

        fun clickSendStatic(timeoutMs: Long): Boolean {
            return instance?.clickSendInternal(timeoutMs) ?: false
        }

        fun typeInInputStatic(text: String): Boolean {
            return instance?.typeInInputInternal(text) ?: false
        }

        fun goBackStatic(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_BACK) ?: false
        }

        fun goHomeStatic(): Boolean {
            return instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        try {
            val info = serviceInfo
            info.flags = info.flags or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            info.notificationTimeout = 30
            serviceInfo = info
        } catch (e: Exception) {
            Log.e(TAG, "config", e)
        }
        Log.d(TAG, "Service connected")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // مفيش معالجة هنا — بس للـ clickSend و typeInInput
    }

    // ═══════════════════ زر الإرسال ═══════════════════
    private fun clickSendInternal(timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        var attempts = 0

        while (System.currentTimeMillis() < deadline) {
            attempts++
            try {
                val node = findSendButton()
                if (node != null) {
                    if (performClick(node)) {
                        Log.d(TAG, "Send clicked after $attempts attempts")
                        return true
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "clickSend error", e)
            }

            try {
                Thread.sleep(300)
            } catch (_: InterruptedException) {
                return false
            }
        }

        Log.w(TAG, "Send button not found after $attempts attempts")
        return false
    }

    private fun findSendButton(): AccessibilityNodeInfo? {
        val roots = collectRoots()

        // 1) ID معروف
        val ids = listOf(
            "com.whatsapp:id/send",
            "com.whatsapp.w4b:id/send",
            "com.whatsapp:id/send_button",
            "com.whatsapp.w4b:id/send_button"
        )
        for (root in roots) {
            for (id in ids) {
                try {
                    val list = root.findAccessibilityNodeInfosByViewId(id)
                    if (list != null && list.isNotEmpty()) {
                        val n = list[0]
                        if (n.isVisibleToUser) return n
                    }
                } catch (_: Exception) {}
            }
        }

        // 2) contentDescription
        val descs = listOf(
            "Send", "send", "SEND",
            "إرسال", "ارسال",
            "Send message",
            "إرسال الرسالة"
        )
        for (root in roots) {
            for (desc in descs) {
                try {
                    val list = root.findAccessibilityNodeInfosByText(desc)
                    if (list != null && list.isNotEmpty()) {
                        val n = list[0]
                        if (n.isVisibleToUser) return n
                    }
                } catch (_: Exception) {}
            }
        }

        // 3) Fallback: زر في أسفل-يمين الشاشة
        val screenHeight = resources.displayMetrics.heightPixels
        val screenWidth = resources.displayMetrics.widthPixels
        var best: AccessibilityNodeInfo? = null
        var bestScore = -1

        for (root in roots) {
            walkNodes(root) { node ->
                try {
                    if (!node.isVisibleToUser) return@walkNodes
                    if (!node.isClickable) return@walkNodes

                    val rect = Rect()
                    node.getBoundsInScreen(rect)

                    val bottomPortion = rect.centerY() > screenHeight * 0.7
                    val rightPortion = rect.centerX() > screenWidth * 0.7
                    val reasonableSize = rect.width() < 300 &&
                            rect.height() < 300 &&
                            rect.width() > 20 &&
                            rect.height() > 20

                    if (bottomPortion && rightPortion && reasonableSize) {
                        val score = (rect.centerX() + rect.centerY()).toInt()
                        if (score > bestScore) {
                            bestScore = score
                            best = node
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        return best
    }

    // ═══════════════════ حقل الكتابة ═══════════════════
    private fun typeInInputInternal(text: String): Boolean {
        val roots = collectRoots()

        // 1) ID معروف لحقل الكتابة
        val ids = listOf(
            "com.whatsapp:id/entry",
            "com.whatsapp.w4b:id/entry"
        )
        for (root in roots) {
            for (id in ids) {
                try {
                    val list = root.findAccessibilityNodeInfosByViewId(id)
                    if (list != null && list.isNotEmpty()) {
                        val node = list[0]
                        if (node.isVisibleToUser && node.isEditable) {
                            if (setTextInNode(node, text)) {
                                Log.d(TAG, "text set via id=$id")
                                return true
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        // 2) Fallback: أول حقل قابل للكتابة في أسفل الشاشة
        val screenHeight = resources.displayMetrics.heightPixels
        var best: AccessibilityNodeInfo? = null
        var bestY = -1

        for (root in roots) {
            walkNodes(root) { node ->
                try {
                    if (!node.isVisibleToUser) return@walkNodes
                    if (!node.isEditable) return@walkNodes

                    val rect = Rect()
                    node.getBoundsInScreen(rect)

                    if (rect.centerY() > screenHeight * 0.75) {
                        if (rect.centerY() > bestY) {
                            bestY = rect.centerY()
                            best = node
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        if (best != null) {
            if (setTextInNode(best!!, text)) {
                Log.d(TAG, "text set via fallback")
                return true
            }
        }

        Log.w(TAG, "input field not found")
        return false
    }

    private fun setTextInNode(node: AccessibilityNodeInfo, text: String): Boolean {
        try {
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        } catch (_: Exception) {}

        return try {
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (_: Exception) {
            false
        }
    }

    // ═══════════════════ Helpers ═══════════════════
    private fun collectRoots(): List<AccessibilityNodeInfo> {
        val roots = mutableListOf<AccessibilityNodeInfo>()
        try {
            val wins = windows
            if (!wins.isNullOrEmpty()) {
                for (w in wins) {
                    val r = w.root ?: continue
                    roots.add(r)
                }
            }
        } catch (_: Exception) {}
        if (roots.isEmpty()) {
            rootInActiveWindow?.let { roots.add(it) }
        }
        return roots
    }

    private fun walkNodes(
        node: AccessibilityNodeInfo?,
        action: (AccessibilityNodeInfo) -> Unit
    ) {
        if (node == null) return
        try {
            node.refresh()
            action(node)
            for (i in 0 until node.childCount) {
                walkNodes(node.getChild(i), action)
            }
        } catch (_: Exception) {}
    }

    private fun performClick(node: AccessibilityNodeInfo): Boolean {
        try {
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
        } catch (_: Exception) {}

        try {
            var p = node.parent
            var d = 0
            while (p != null && d < 5) {
                if (p.isClickable &&
                    p.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                ) {
                    return true
                }
                p = p.parent
                d++
            }
        } catch (_: Exception) {}

        return gestureTap(node)
    }

    private fun gestureTap(node: AccessibilityNodeInfo): Boolean {
        return try {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) return false

            val path = Path().apply {
                moveTo(rect.exactCenterX(), rect.exactCenterY())
            }
            val stroke = GestureDescription.StrokeDescription(path, 0, 60)
            val gesture = GestureDescription.Builder()
                .addStroke(stroke).build()

            dispatchGesture(gesture, null, mainHandler)
            true
        } catch (e: Exception) {
            Log.e(TAG, "gestureTap", e)
            false
        }
    }
}