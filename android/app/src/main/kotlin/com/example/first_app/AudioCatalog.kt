package com.example.first_app

import android.content.Context

object AudioCatalog {
    private val _tracks = mutableListOf<AudioTrack>()

    val tracks: List<AudioTrack>
        get() = _tracks

    fun loadFromDevice(context: Context) {
        _tracks.clear()
        _tracks.addAll(AudioDeviceLibrary.queryTracks(context))
    }

    fun hasTracks(): Boolean = _tracks.isNotEmpty()

    fun trackAt(index: Int): AudioTrack = _tracks[index]
}
