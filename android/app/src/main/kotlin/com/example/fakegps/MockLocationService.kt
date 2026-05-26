package com.example.fakegps

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class MockLocationService : Service() {

    companion object {
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        private const val CHANNEL_ID = "fake_gps_channel"
        private const val NOTIFICATION_ID = 1001
        private const val PROVIDER = LocationManager.GPS_PROVIDER
    }

    private lateinit var locationManager: LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private var latitude = 0.0
    private var longitude = 0.0
    private var isRunning = false

    private val broadcastRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                pushMockLocation(latitude, longitude)
                handler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                latitude = intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
                longitude = intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
                startForeground(NOTIFICATION_ID, buildNotification())
                startMocking()
            }
            ACTION_UPDATE -> {
                latitude = intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
                longitude = intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
                updateNotification()
            }
            ACTION_STOP -> {
                stopMocking()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startMocking() {
        try {
            if (locationManager.allProviders.contains(PROVIDER)) {
                try {
                    locationManager.removeTestProvider(PROVIDER)
                } catch (_: Exception) {}
            }
            locationManager.addTestProvider(
                PROVIDER,
                false, false, false, false, false,
                true, true,
                Criteria.POWER_LOW,
                Criteria.ACCURACY_FINE
            )
            locationManager.setTestProviderEnabled(PROVIDER, true)
            isRunning = true
            handler.post(broadcastRunnable)
        } catch (e: SecurityException) {
            stopSelf()
        }
    }

    private fun stopMocking() {
        isRunning = false
        handler.removeCallbacks(broadcastRunnable)
        try {
            locationManager.setTestProviderEnabled(PROVIDER, false)
            locationManager.removeTestProvider(PROVIDER)
        } catch (_: Exception) {}
    }

    private fun pushMockLocation(lat: Double, lng: Double) {
        try {
            val location = Location(PROVIDER).apply {
                latitude = lat
                longitude = lng
                altitude = 10.0
                accuracy = 1.0f
                speed = 0.0f
                bearing = 0.0f
                time = System.currentTimeMillis()
                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    verticalAccuracyMeters = 1.0f
                    speedAccuracyMetersPerSecond = 0.01f
                    bearingAccuracyDegrees = 0.1f
                }
            }
            locationManager.setTestProviderLocation(PROVIDER, location)
        } catch (_: Exception) {}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Fake GPS",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Fake GPS đang chạy nền"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fake GPS đang hoạt động")
            .setContentText(formatCoords())
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun formatCoords(): String =
        "%.6f, %.6f".format(latitude, longitude)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopMocking()
    }
}
