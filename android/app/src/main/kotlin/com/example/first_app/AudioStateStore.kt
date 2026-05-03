package com.example.first_app

object AudioStateStore {
    @Volatile
    var state: AudioPlaybackState = AudioPlaybackState(
        currentIndex = 0,
        isPlaying = false,
        track = AudioTrack.EMPTY,
        hasTracks = false,
        permissionGranted = true,
    )

    fun setPermissionGranted(granted: Boolean) {
        if (!granted) {
            state = AudioPlaybackState(
                currentIndex = 0,
                isPlaying = false,
                track = AudioTrack.EMPTY,
                hasTracks = false,
                permissionGranted = false,
            )
            return
        }

        syncWithCatalog(currentIndex = 0, isPlaying = false)
    }

    fun syncWithCatalog(currentIndex: Int = 0, isPlaying: Boolean = false) {
        if (!AudioCatalog.hasTracks()) {
            state = AudioPlaybackState(
                currentIndex = 0,
                isPlaying = false,
                track = AudioTrack.EMPTY,
                hasTracks = false,
                permissionGranted = true,
            )
            return
        }

        val safeIndex = currentIndex.coerceIn(0, AudioCatalog.tracks.lastIndex)
        state = AudioPlaybackState(
            currentIndex = safeIndex,
            isPlaying = isPlaying,
            track = AudioCatalog.trackAt(safeIndex),
            hasTracks = true,
            permissionGranted = true,
        )
    }

    fun update(currentIndex: Int, isPlaying: Boolean) {
        syncWithCatalog(currentIndex = currentIndex, isPlaying = isPlaying)
    }
}
