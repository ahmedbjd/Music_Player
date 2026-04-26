package com.example.first_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import java.io.File
import java.io.InputStream
import java.io.OutputStream

class MusicService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var assetFilename: String? = null
    private val CHANNEL_ID = "music_player_channel"
    private val NOTIFICATION_ID = 1

    // Intent actions
    companion object {
        const val ACTION_PLAY = "com.example.first_app.PLAY"
        const val ACTION_PAUSE = "com.example.first_app.PAUSE"
        const val ACTION_STOP = "com.example.first_app.STOP"
        const val ACTION_STOP_AND_EXIT = "com.example.first_app.STOP_AND_EXIT"
        const val ACTION_PLAYBACK_STATE_CHANGED = "com.example.first_app.PLAYBACK_STATE_CHANGED"
        const val EXTRA_ASSET_FILENAME = "asset_filename"
        const val EXTRA_IS_PLAYING = "is_playing"
        @Volatile
        var isPlayingNow = false
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val filename = intent.getStringExtra(EXTRA_ASSET_FILENAME)
                if (filename != null) {
                    playAudio(filename)
                }
            }
            ACTION_PAUSE -> {
                pauseAudio()
            }
            ACTION_STOP -> {
                stopAudio()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_STOP_AND_EXIT -> {
                stopAudio()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                exitApp()
            }
        }
        return START_STICKY
    }

    private fun playAudio(assetFilename: String) {
        try {
            // Release previous player if exists
            mediaPlayer?.release()
            mediaPlayer = null

            // Copy asset to cache file
            val cacheFile = copyAssetToCache(assetFilename)
            this.assetFilename = assetFilename

            // Create new MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                setDataSource(cacheFile.absolutePath)
                setOnCompletionListener {
                    updatePlaybackState(false)
                    stopForeground(STOP_FOREGROUND_DETACH)
                }
                prepare()
                start()
            }
            updatePlaybackState(true)

            // Show persistent notification
            showNotification(true)
        } catch (e: Exception) {
            updatePlaybackState(false)
            e.printStackTrace()
        }
    }

    private fun pauseAudio() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    pause()
                }
            }
            updatePlaybackState(false)
            showNotification(false)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            updatePlaybackState(false)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun copyAssetToCache(assetFilename: String): File {
        val cacheDir = cacheDir
        val cacheFile = File(cacheDir, assetFilename.replace("/", "_"))

        if (!cacheFile.exists()) {
            try {
                val flutterAssetPath = if (assetFilename.startsWith("assets/")) {
                    assetFilename
                } else {
                    "assets/$assetFilename"
                }
                val lookupKey = FlutterInjector.instance()
                    .flutterLoader()
                    .getLookupKeyForAsset(flutterAssetPath)
                val inputStream: InputStream = assets.open(lookupKey)
                val outputStream: OutputStream = cacheFile.outputStream()

                inputStream.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        return cacheFile
    }

    private fun showNotification(isPlaying: Boolean) {
        val playPauseAction = if (isPlaying) {
            // Pause action
            val pauseIntent = Intent(this, MusicService::class.java).apply {
                action = ACTION_PAUSE
            }
            val pausePendingIntent = PendingIntent.getService(
                this,
                1,
                pauseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause,
                "Pause",
                pausePendingIntent
            )
        } else {
            // Play action
            val playIntent = Intent(this, MusicService::class.java).apply {
                action = ACTION_PLAY
                putExtra(EXTRA_ASSET_FILENAME, assetFilename)
            }
            val playPendingIntent = PendingIntent.getService(
                this,
                2,
                playIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            NotificationCompat.Action(
                android.R.drawable.ic_media_play,
                "Play",
                playPendingIntent
            )
        }

        // Stop action
        val stopIntent = Intent(this, MusicService::class.java).apply {
            action = ACTION_STOP_AND_EXIT
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            3,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Music Player")
            .setContentText(assetFilename ?: "Playing...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .addAction(playPauseAction)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent
            )
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Music Player",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifications for music playback"
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun updatePlaybackState(isPlaying: Boolean) {
        isPlayingNow = isPlaying
        val stateIntent = Intent(ACTION_PLAYBACK_STATE_CHANGED).apply {
            setPackage(packageName)
            putExtra(EXTRA_IS_PLAYING, isPlaying)
        }
        sendBroadcast(stateIntent)
    }

    private fun exitApp() {
        val exitIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_EXIT_APP, true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(exitIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        updatePlaybackState(false)
        stopAudio()
    }
}
