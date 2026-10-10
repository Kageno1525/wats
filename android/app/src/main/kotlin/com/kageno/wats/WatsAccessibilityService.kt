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

        @Volatile
        var onProgress: ((String) -> Unit)? = null

        @Volatile
        var onDone: ((Int, Int) -> Unit)? = null

        @Volatile
        private var cachedSendId: String? = null

        @Volatile
        private var cachedInputId: String? = null

        fun typeInInputStatic(text: String): Boolean {
            return instance?.typeInInputInternal(text) ?: false
        }

        /**
         * ⭐ الدالة الرئيسية — بترسل كل الرسائل مرة واحدة
         * من غير رجوع للـ Flutter بين كل رسالة
         */
        fun sendBulkStatic(
            message: String,
            count: Int,
            delayMs: Long,
        ) {
            instance?.sendBulkInternal(message, count, delayMs)
        }

        fun stopBulk() {
            instance?.stopRequested = true
        }

        fun clearCache() {
            cachedSendId = null
            cachedInputId = null
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var stopRequested = false

    private val sendIds = listOf(
        "com.whatsapp:id/send",
        "com.whatsapp.w4b:id/send",
        "com.whatsapp:id/send_button",
        "com.whatsapp.w4b:id/send_button"
    )
    private val inputIds = listOf(
        "com.whatsapp:id/entry",
        "com.whatsapp.w4b:id/entry"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        try {
            val info = serviceInfo
            info.flags = info.flags or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            info.notificationTimeout = 20
            serviceInfo = info
        } catch (e: Exception) {
            Log.e(TAG, "config", e)
        }
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    // ═══════════════════ Bulk Send ═══════════════════
    private fun sendBulkInternal(message: String, count: Int, delayMs: Long) {
        stopRequested = false

        Thread {
            val startMs = System.currentTimeMillis()
            var sentCount = 0
            var failedCount = 0

            progress("بدء $count رسالة")

            for (i in 1..count) {
                if (stopRequested) {
                    progress("⏹ اتوقف")
                    break
                }

                progress("▶️ $i/$count")

                try {
                    // 1) اكتب الرسالة
                    val typed = typeInInputInternal(message)
                    if (!typed) {
                        failedCount++
                        progress("⚠️ فشل الكتابة ($i)")
                        sleepMs(200)
                        continue
                    }

                    // 2) اضغط إرسال (بمحاولة سريعة)
                    val sent = clickSendInternal(1500)
                    if (sent) {
                        sentCount++
                        progress("✅ $i")
                    } else {
                        failedCount++
                        progress("⚠️ زر الإرسال مش موجود ($i)")
                    }

                    // 3) فاصل قصير جداً بين الرسائل
                    if (i < count && delayMs > 0) {
                        sleepMs(delayMs)
                    } else if (i < count) {
                        sleepMs(50) // 50ms بس عشان WhatsApp يلحق
                    }
                } catch (e: Exception) {
                    failedCount++
                    Log.e(TAG, "send error", e)
                    progress("❌ خطأ في $i")
                }
            }

            val elapsed = System.currentTimeMillis() - startMs
            val elapsedSec = elapsed / 1000.0
            val avg = if (sentCount > 0) elapsedSec / sentCount else 0.0

            progress("═══ خلصنا: ✅ $sentCount | ⚠️ $failedCount | ⏱ ${"%.1f".format(elapsedSec)}ث | متوسط ${"%.2f".format(avg)}ث/رسالة")

            try {
                onDone?.invoke(sentCount, failedCount)
            } catch (_: Exception) {}
        }.start()
    }

    private fun progress(msg: String) {
        try {
            onProgress?.invoke(msg)
        } catch (_: Exception) {}
    }

    private fun sleepMs(ms: Long) {
        try {
            Thread.sleep(ms)
        } catch (_: InterruptedException) {}
    }

    // ═══════════════════ زر الإرسال (سريع) ═══════════════════
    private fun clickSendInternal(timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs

        while (System.currentTimeMillis() < deadline) {
            // Cache first
            val cached = cachedSendId
            if (cached != null) {
                val n = findByViewIdFast(cached)
                if (n != null && performClick(n)) {
                    return true
                }
                cachedSendId = null
            }

            // Try known IDs
            for (id in sendIds) {
                val n = findByViewIdFast(id)
                if (n != null) {
                    if (performClick(n)) {
                        cachedSendId = id
                        return true
                    }
                }
            }

            sleepMs(20)
        }
        return false
    }

    // ═══════════════════ كتابة سريعة ═══════════════════
    private fun typeInInputInternal(text: String): Boolean {
        // Cache first
        val cached = cachedInputId
        if (cached != null) {
            val n = findByViewIdFast(cached)
            if (n != null && n.isEditable) {
                if (setTextInNode(n, text)) return true
                cachedInputId = null
            }
        }

        // Try known IDs
        for (id in inputIds) {
            val n = findByViewIdFast(id)
            if (n != null && n.isEditable) {
                if (setTextInNode(n, text)) {
                    cachedInputId = id
                    return true
                }
            }
        }

        // Fallback
        val n = findInputFallbackFast()
        if (n != null && setTextInNode(n, text)) {
            return true
        }

        return false
    }

    // ═══════════════════ Helpers ═══════════════════
    private fun findByViewIdFast(id: String): AccessibilityNodeInfo? {
        try {
            val active = rootInActiveWindow ?: return null
            val list = active.findAccessibilityNodeInfosByViewId(id)
            if (list != null && list.isNotEmpty()) {
                val n = list[0]
                if (n.isVisibleToUser) return n
            }
        } catch (_: Exception) {}
        return null
    }

    private fun findInputFallbackFast(): AccessibilityNodeInfo? {
        val active = rootInActiveWindow ?: return null
        val screenHeight = resources.displayMetrics.heightPixels

        var best: AccessibilityNodeInfo? = null
        var bestY = -1
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(active)

        var iter = 0
        while (queue.isNotEmpty() && iter < 200) {
            iter++
            val node = queue.removeFirst()
            try {
                if (node.isVisibleToUser && node.isEditable) {
                    val rect = Rect()
                    node.getBoundsInScreen(rect)
                    if (rect.centerY() > screenHeight * 0.75 &&
                        rect.centerY() > bestY
                    ) {
                        bestY = rect.centerY()
                        best = node
                    }
                }
                for (i in 0 until node.childCount) {
                    node.getChild(i)?.let { queue.add(it) }
                }
            } catch (_: Exception) {}
        }
        return best
    }

    private fun setTextInNode(node: AccessibilityNodeInfo, text: String): Boolean {
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

    private fun performClick(node: AccessibilityNodeInfo): Boolean {
        try {
            if (node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
        } catch (_: Exception) {}
        return false
    }
}