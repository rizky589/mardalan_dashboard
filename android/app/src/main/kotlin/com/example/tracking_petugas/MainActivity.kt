package com.example.tracking_petugas

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.location.LocationManager
import android.provider.Settings
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "gps_detector"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMockLocationEnabled" -> {
                    val isMockEnabled = isMockLocationEnabled()
                    result.success(isMockEnabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isMockLocationEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Check if mock location app is enabled in developer options
                val mockLocation = Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0
                )
                mockLocation != 0
            } else {
                // For older versions, check if mock locations are allowed
                val mockLocation = Settings.Secure.getInt(
                    contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0
                )
                mockLocation != 0
            }
        } catch (e: Exception) {
            false
        }
    }
}
