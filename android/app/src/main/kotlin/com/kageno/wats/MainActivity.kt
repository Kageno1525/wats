package com.kageno.wats

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "wats/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityEnabled())
                }

                "openAccessibilitySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        )
                    } catch (_: Exception) {}
                    result.success(null)
                }

                "isWhatsAppInstalled" -> {
                    val business = call.argument<Boolean>("business") ?: false
                    val pkg = if (business) "com.whatsapp.w4b" else "com.whatsapp"
                    val installed = try {
                        packageManager.getPackageInfo(pkg, 0)
                        true
                    } catch (_: Exception) {
                        false
                    }
                    result.success(installed)
                }

                "openWhatsApp" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val business = call.argument<Boolean>("business") ?: false

                    Thread {
                        val ok = openWhatsApp(phone, message, business)
                        Handler(Looper.getMainLooper()).post {
                            result.success(ok)
                        }
                    }.start()
                }

                "clickSend" -> {
                    val timeout = call.argument<Int>("timeout") ?: 6000
                    Thread {
                        val ok = WatsAccessibilityService.clickSendStatic(
                            timeout.toLong()
                        )
                        Handler(Looper.getMainLooper()).post {
                            result.success(ok)
                        }
                    }.start()
                }

                "goBack" -> {
                    WatsAccessibilityService.goBackStatic()
                    result.success(null)
                }

                "goHome" -> {
                    WatsAccessibilityService.goHomeStatic()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * يفتح واتساب بالرقم والرسالة الجاهزة
     * يستخدم intent رسمي من واتساب
     */
    private fun openWhatsApp(
        phone: String,
        message: String,
        business: Boolean
    ): Boolean {
        try {
            val cleanPhone = phone.replace(Regex("[^0-9]"), "")
            if (cleanPhone.isEmpty()) return false

            val encodedMsg = Uri.encode(message)

            // 1) جرّب whatsapp scheme الرسمي
            val scheme = if (business) "whatsapp-business" else "whatsapp"
            val uri = Uri.parse("$scheme://send?phone=$cleanPhone&text=$encodedMsg")
            val intent = Intent(Intent.ACTION_VIEW, uri)

            // 2) تحديد الباكدج المناسب
            intent.setPackage(
                if (business) "com.whatsapp.w4b" else "com.whatsapp"
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // 3) fallback: استخدم wa.me URL
            }

            val waUrl = "https://wa.me/$cleanPhone?text=$encodedMsg"
            val fallback = Intent(Intent.ACTION_VIEW, Uri.parse(waUrl))
            fallback.setPackage(
                if (business) "com.whatsapp.w4b" else "com.whatsapp"
            )
            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            try {
                startActivity(fallback)
                return true
            } catch (_: Exception) {
                // 4) fallback أخير: من غير تحديد الباكدج
            }

            val browserFallback = Intent(
                Intent.ACTION_VIEW,
                Uri.parse(waUrl)
            )
            browserFallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            return try {
                startActivity(browserFallback)
                true
            } catch (_: Exception) {
                false
            }
        } catch (e: Exception) {
            return false
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val service = "$packageName/${WatsAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.split(':').any { it.equals(service, ignoreCase = true) }
    }
}