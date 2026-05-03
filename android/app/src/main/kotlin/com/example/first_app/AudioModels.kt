package com.example.first_app

data class AudioTrack(
    val title: String,
    val file: String,
    val author: String,
    val description: String
) {
    fun toMap(): Map<String, String> {
        return mapOf(
            "title" to title,
            "file" to file,
            "author" to author,
            "description" to description,
        )
    }

    companion object {
        val EMPTY = AudioTrack(
            title = "",
            file = "",
            author = "",
            description = "",
        )
    }
}

data class AudioPlaybackState(
    val currentIndex: Int,
    val isPlaying: Boolean,
    val track: AudioTrack,
    val hasTracks: Boolean,
    val permissionGranted: Boolean,
) {
    fun toMap(): Map<String, Any> {
        return mapOf(
            "currentIndex" to currentIndex,
            "isPlaying" to isPlaying,
            "track" to track.toMap(),
            "hasTracks" to hasTracks,
            "permissionGranted" to permissionGranted,
        )
    }
}
