package com.example.first_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val notificationPermissionCode = 1001
    private val audioPermissionCode = 1002
    private var audioStateReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    result.success(initializeAudioLibrary().toMap())
                }

                "playPause" -> {
                    AudioPlaybackService.startCommand(this, AudioPlaybackService.ACTION_PLAY_PAUSE)
                    result.success(null)
                }

                "next" -> {
                    AudioPlaybackService.startCommand(this, AudioPlaybackService.ACTION_NEXT)
                    result.success(null)
                }

                "previous" -> {
                    AudioPlaybackService.startCommand(this, AudioPlaybackService.ACTION_PREVIOUS)
                    result.success(null)
                }

                "getState" -> {
                    result.success(AudioStateStore.state.toMap())
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent?.action != AudioPlaybackService.ACTION_STATE_CHANGED) {
                            return
                        }

                        events.success(AudioStateStore.state.toMap())
                    }
                }

                audioStateReceiver = receiver
                registerAudioStateReceiver(receiver)
                events.success(AudioStateStore.state.toMap())
            }

            override fun onCancel(arguments: Any?) {
                audioStateReceiver?.let { unregisterReceiver(it) }
                audioStateReceiver = null
            }
        })
    }

    override fun onResume() {
        super.onResume()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionCode,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != audioPermissionCode) {
            return
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        if (granted) {
            initializeAudioLibrary()
            return
        }

        AudioStateStore.setPermissionGranted(false)
        AudioPlaybackService.broadcastState(this)
    }

    private fun initializeAudioLibrary(): AudioPlaybackState {
        if (!hasAudioPermission()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(audioPermissionName()),
                audioPermissionCode,
            )
            AudioStateStore.setPermissionGranted(false)
            return AudioStateStore.state
        }

        AudioCatalog.loadFromDevice(this)
        AudioStateStore.setPermissionGranted(true)
        AudioPlaybackService.startCommand(this, AudioPlaybackService.ACTION_INITIALIZE)
        return AudioStateStore.state
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            audioPermissionName(),
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun audioPermissionName(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun registerAudioStateReceiver(receiver: BroadcastReceiver) {
        val filter = IntentFilter(AudioPlaybackService.ACTION_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            return
        }

        @Suppress("DEPRECATION")
        registerReceiver(receiver, filter)
    }

    companion object {
        private const val METHOD_CHANNEL = "com.example.first_app/audio"
        private const val EVENT_CHANNEL = "com.example.first_app/audio_state"
    }
}
