package com.example.first_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.music/service"
    private val PLAYBACK_EVENTS = "com.example.music/playback_events"
    private val NOTIFICATION_PERMISSION_CODE = 1001

    private var playbackEventSink: EventChannel.EventSink? = null
    private val playbackStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != MusicService.ACTION_PLAYBACK_STATE_CHANGED) {
                return
            }
            val isPlaying = intent.getBooleanExtra(MusicService.EXTRA_IS_PLAYING, false)
            playbackEventSink?.success(isPlaying)
        }
    }

    companion object {
        const val EXTRA_EXIT_APP = "exit_app"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleExitIntent(intent)
        val filter = IntentFilter(MusicService.ACTION_PLAYBACK_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(playbackStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(playbackStateReceiver, filter)
        }
    }

    override fun onResume() {
        super.onResume()
        // Request notification permission on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleExitIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYBACK_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    playbackEventSink = events
                    events?.success(MusicService.isPlayingNow)
                }

                override fun onCancel(arguments: Any?) {
                    playbackEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val assetFilename = call.argument<String>("filename")
                    if (assetFilename != null) {
                        startMusicService(assetFilename)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "filename is required", null)
                    }
                }
                "pauseService" -> {
                    pauseMusicService()
                    result.success(null)
                }
                "stopService" -> {
                    stopMusicService()
                    result.success(null)
                }
                "getPlaybackState" -> {
                    result.success(MusicService.isPlayingNow)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun handleExitIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_EXIT_APP, false) == true) {
            finishAffinity()
        }
    }

    override fun onDestroy() {
        unregisterReceiver(playbackStateReceiver)
        playbackEventSink = null
        super.onDestroy()
    }

    private fun startMusicService(filename: String) {
        val intent = Intent(this, MusicService::class.java).apply {
            action = MusicService.ACTION_PLAY
            putExtra(MusicService.EXTRA_ASSET_FILENAME, filename)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun pauseMusicService() {
        val intent = Intent(this, MusicService::class.java).apply {
            action = MusicService.ACTION_PAUSE
        }
        startService(intent)
    }

    private fun stopMusicService() {
        val intent = Intent(this, MusicService::class.java).apply {
            action = MusicService.ACTION_STOP
        }
        startService(intent)
    }
}
