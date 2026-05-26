package com.example.fakegps

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.example.fakegps/mock_location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val lat = call.argument<Double>("latitude") ?: 0.0
                val lng = call.argument<Double>("longitude") ?: 0.0
                when (call.method) {
                    "startMockLocation" -> {
                        val intent = Intent(this, MockLocationService::class.java).apply {
                            action = MockLocationService.ACTION_START
                            putExtra(MockLocationService.EXTRA_LATITUDE, lat)
                            putExtra(MockLocationService.EXTRA_LONGITUDE, lng)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "updateLocation" -> {
                        val intent = Intent(this, MockLocationService::class.java).apply {
                            action = MockLocationService.ACTION_UPDATE
                            putExtra(MockLocationService.EXTRA_LATITUDE, lat)
                            putExtra(MockLocationService.EXTRA_LONGITUDE, lng)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "stopMockLocation" -> {
                        val intent = Intent(this, MockLocationService::class.java).apply {
                            action = MockLocationService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
