package com.sonialabs.sonaxia

import android.content.Intent
import android.os.Bundle
package com.sonialabs.sonaxia

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()

    private val CHANNEL = "sonaxia/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSharedData") {
                result.success(handleIntent(intent))
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun handleIntent(intent: Intent?): String? {
        if (intent == null) return null

        if (intent.action == Intent.ACTION_SEND) {
            return when {
                intent.type?.startsWith("image/") == true ->
                    intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.toString()

                intent.type == "application/pdf" ->
                    intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)?.toString()

                intent.type == "text/plain" ->
                    intent.getStringExtra(Intent.EXTRA_TEXT)

                else -> null
            }
        }

        return null
    }
}