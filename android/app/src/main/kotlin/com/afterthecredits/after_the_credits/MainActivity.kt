package com.afterthecredits.after_the_credits

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.webkit.CookieManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.afterthecredits/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                try {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.flush()

                    val urls = arrayOf(
                        "https://letterboxd.com/",
                        "https://letterboxd.com",
                        "https://m.letterboxd.com/",
                        "https://m.letterboxd.com",
                        "https://.letterboxd.com"
                    )

                    val map = LinkedHashMap<String, String>()
                    for (u in urls) {
                        val cStr = cookieManager.getCookie(u) ?: continue
                        for (part in cStr.split(";")) {
                            val trimmed = part.trim()
                            val eqIdx = trimmed.indexOf('=')
                            if (eqIdx > 0) {
                                val key = trimmed.substring(0, eqIdx).trim()
                                val value = trimmed.substring(eqIdx + 1).trim()
                                map[key] = value
                            }
                        }
                    }

                    val joined = map.entries.joinToString("; ") { "${it.key}=${it.value}" }
                    result.success(joined)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
