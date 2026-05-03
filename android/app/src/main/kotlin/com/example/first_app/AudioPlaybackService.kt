package com.example.first_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

class AudioPlaybackService : Service(), SensorEventListener {

    private var mediaPlayer: MediaPlayer? = null
    private var currentIndex = AudioStateStore.state.currentIndex
    private var isForeground = false
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var lastShakeAt = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerShakeDetection()
        initializePlaybackIfPossible()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_INITIALIZE -> initializePlaybackIfPossible()
            ACTION_PLAY_PAUSE -> handlePlayPause()
            ACTION_NEXT -> playIndex(nextIndex(), autoPlay = true)
            ACTION_PREVIOUS -> playIndex(previousIndex(), autoPlay = true)
            ACTION_STOP -> stopPlayback()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        unregisterShakeDetection()
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val values = event?.values ?: return
        if (values.size < 3) return

        val x = values[0]
        val y = values[1]
        val z = values[2]
        val acceleration = kotlin.math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        val normalizedAcceleration = acceleration / SensorManager.GRAVITY_EARTH

        if (normalizedAcceleration < SHAKE_THRESHOLD_GRAVITY) {
            return
        }

        val now = System.currentTimeMillis()
        if (now - lastShakeAt < SHAKE_COOLDOWN_MS) {
            return
        }

        lastShakeAt = now
        handlePlayPause()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun initializePlaybackIfPossible() {
        if (!AudioCatalog.hasTracks()) {
            AudioStateStore.syncWithCatalog()
            notifyStateChanged()
            return
        }

        currentIndex = currentIndex.coerceIn(0, AudioCatalog.tracks.lastIndex)
        if (mediaPlayer == null) {
            prepareTrack(currentIndex, autoPlay = false)
            return
        }

        AudioStateStore.update(currentIndex = currentIndex, isPlaying = mediaPlayer?.isPlaying == true)
        notifyStateChanged()
    }

    private fun handlePlayPause() {
        if (!AudioCatalog.hasTracks()) {
            notifyStateChanged()
            return
        }

        val player = mediaPlayer ?: run {
            prepareTrack(currentIndex, autoPlay = true)
            return
        }

        if (player.isPlaying) {
            player.pause()
            updateState(isPlaying = false)
            stopForegroundMode()
            return
        }

        player.start()
        updateState(isPlaying = true)
        startForegroundMode()
    }

    private fun stopPlayback() {
        mediaPlayer?.apply {
            if (isPlaying) {
                stop()
            }
            reset()
            release()
        }
        mediaPlayer = null
        updateState(isPlaying = false)
        removeForegroundNotification()
        isForeground = false
        stopSelf()
    }

    private fun playIndex(index: Int, autoPlay: Boolean) {
        if (!AudioCatalog.hasTracks()) {
            notifyStateChanged()
            return
        }

        currentIndex = index
        prepareTrack(index, autoPlay)
    }

    private fun prepareTrack(index: Int, autoPlay: Boolean) {
        if (!AudioCatalog.hasTracks()) {
            AudioStateStore.syncWithCatalog()
            notifyStateChanged()
            return
        }

        mediaPlayer?.release()

        val track = AudioCatalog.trackAt(index)
        mediaPlayer = MediaPlayer().apply {
            setDataSource(this@AudioPlaybackService, Uri.parse(track.file))
            isLooping = false
            setOnCompletionListener {
                playIndex(nextIndex(), autoPlay = true)
            }
            prepare()
            if (autoPlay) {
                start()
            }
        }

        updateState(isPlaying = autoPlay)
        if (autoPlay) {
            startForegroundMode()
        } else {
            stopForegroundMode()
        }
    }

    private fun updateState(isPlaying: Boolean) {
        AudioStateStore.update(currentIndex = currentIndex, isPlaying = isPlaying)
        notifyStateChanged()
    }

    private fun notifyStateChanged() {
        sendBroadcast(
            Intent(ACTION_STATE_CHANGED).apply {
                `package` = packageName
            },
        )
    }

    private fun nextIndex(): Int {
        if (!AudioCatalog.hasTracks()) {
            return 0
        }
        return (currentIndex + 1) % AudioCatalog.tracks.size
    }

    private fun previousIndex(): Int {
        if (!AudioCatalog.hasTracks()) {
            return 0
        }
        return (currentIndex - 1 + AudioCatalog.tracks.size) % AudioCatalog.tracks.size
    }

    private fun startForegroundMode() {
        val notification = buildNotification(AudioStateStore.state)
        if (isForeground) {
            showNotification(notification)
            return
        }

        startForeground(NOTIFICATION_ID, notification)
        isForeground = true
    }

    private fun stopForegroundMode() {
        if (!isForeground) {
            showNotification(buildNotification(AudioStateStore.state))
            return
        }

        removeForegroundNotification()
        isForeground = false
        showNotification(buildNotification(AudioStateStore.state))
    }

    private fun removeForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            return
        }

        @Suppress("DEPRECATION")
        stopForeground(true)
    }

    private fun buildNotification(state: AudioPlaybackState): Notification {
        val previousIntent = PendingIntent.getService(
            this,
            REQUEST_PREVIOUS,
            Intent(this, AudioPlaybackService::class.java).setAction(ACTION_PREVIOUS),
            pendingIntentFlags(),
        )
        val playPauseIntent = PendingIntent.getService(
            this,
            REQUEST_PLAY_PAUSE,
            Intent(this, AudioPlaybackService::class.java).setAction(ACTION_PLAY_PAUSE),
            pendingIntentFlags(),
        )
        val nextIntent = PendingIntent.getService(
            this,
            REQUEST_NEXT,
            Intent(this, AudioPlaybackService::class.java).setAction(ACTION_NEXT),
            pendingIntentFlags(),
        )
        val stopIntent = PendingIntent.getService(
            this,
            REQUEST_STOP,
            Intent(this, AudioPlaybackService::class.java).setAction(ACTION_STOP),
            pendingIntentFlags(),
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(
                if (state.hasTracks) state.track.title else "No audio found",
            )
            .setContentText(
                when {
                    !state.permissionGranted -> "Audio permission is required"
                    state.hasTracks -> state.track.author
                    else -> "No songs available on this device"
                },
            )
            .setOngoing(state.isPlaying)
            .setOnlyAlertOnce(true)
            .setStyle(
                MediaStyle().setShowActionsInCompactView(0, 1, 2),
            )
            .addAction(android.R.drawable.ic_media_previous, "Previous", previousIntent)
            .addAction(
                if (state.isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (state.isPlaying) "Pause" else "Play",
                playPauseIntent,
            )
            .addAction(android.R.drawable.ic_media_next, "Next", nextIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopIntent)
            .build()
    }

    private fun showNotification(notification: Notification) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun pendingIntentFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Music playback",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun registerShakeDetection() {
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelerometer?.let { sensor ->
            sensorManager?.registerListener(
                this,
                sensor,
                SensorManager.SENSOR_DELAY_NORMAL,
            )
        }
    }

    private fun unregisterShakeDetection() {
        sensorManager?.unregisterListener(this)
        accelerometer = null
        sensorManager = null
    }

    companion object {
        const val ACTION_INITIALIZE = "com.example.first_app.audio.INITIALIZE"
        const val ACTION_PLAY_PAUSE = "com.example.first_app.audio.PLAY_PAUSE"
        const val ACTION_NEXT = "com.example.first_app.audio.NEXT"
        const val ACTION_PREVIOUS = "com.example.first_app.audio.PREVIOUS"
        const val ACTION_STOP = "com.example.first_app.audio.STOP"
        const val ACTION_STATE_CHANGED = "com.example.first_app.audio.STATE_CHANGED"

        private const val NOTIFICATION_CHANNEL_ID = "first_app_audio"
        private const val NOTIFICATION_ID = 1001
        private const val REQUEST_PREVIOUS = 2001
        private const val REQUEST_PLAY_PAUSE = 2002
        private const val REQUEST_NEXT = 2003
        private const val REQUEST_STOP = 2004
        private const val SHAKE_COOLDOWN_MS = 1200L
        private const val SHAKE_THRESHOLD_GRAVITY = 2.7f

        fun startCommand(context: Context, action: String) {
            val intent = Intent(context, AudioPlaybackService::class.java).setAction(action)
            context.startService(intent)
        }

        fun broadcastState(context: Context) {
            context.sendBroadcast(
                Intent(ACTION_STATE_CHANGED).apply {
                    `package` = context.packageName
                },
            )
        }
    }
}
