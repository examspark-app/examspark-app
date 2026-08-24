package com.sonialabs.sonaxia

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability

class MainActivity : FlutterActivity() {

    private val CHANNEL = "sonaxia/share"
    private val UPDATE_REQUEST_CODE = 9101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedData" -> result.success(handleIntent(intent))
                "startInAppUpdate" -> startInAppUpdate(result)
                else -> result.notImplemented()
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

    private fun startInAppUpdate(result: MethodChannel.Result) {
        val manager = AppUpdateManagerFactory.create(this)
        manager.appUpdateInfo.addOnSuccessListener { info ->
            val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
            val allowed = info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
            if (!available || !allowed) {
                result.success(false)
                return@addOnSuccessListener
            }
            try {
                manager.startUpdateFlowForResult(
                    info,
                    this,
                    com.google.android.play.core.appupdate.AppUpdateOptions
                        .newBuilder(AppUpdateType.IMMEDIATE)
                        .build(),
                    UPDATE_REQUEST_CODE,
                )
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }.addOnFailureListener { result.success(false) }
    }
}