package com.example.strokeguard

import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.health.connect.client.PermissionController
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.example.strokeguard/health_background"
        private const val BACKGROUND_READ_PERMISSION =
            "android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"
    }

    private var backgroundPermissionResult: MethodChannel.Result? = null

    private val backgroundReadPermissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract(),
    ) { granted ->
        backgroundPermissionResult?.success(BACKGROUND_READ_PERMISSION in granted)
        backgroundPermissionResult = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "requestBackgroundReadPermission") {
                result.notImplemented()
            } else if (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                ContextCompat.checkSelfPermission(
                    this,
                    BACKGROUND_READ_PERMISSION,
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                result.success(true)
            } else if (backgroundPermissionResult != null) {
                result.error("REQUEST_IN_PROGRESS", "Permission request is active.", null)
            } else {
                backgroundPermissionResult = result
                backgroundReadPermissionLauncher.launch(
                    setOf(BACKGROUND_READ_PERMISSION),
                )
            }
        }
    }
}