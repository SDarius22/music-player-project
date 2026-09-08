package com.lucasjosino.on_audio_query.utils

import android.os.Build
import android.provider.MediaStore

// Query songs projection
fun songProjection(): Array<String> {
    val tmpProjection = arrayListOf(
        MediaStore.Audio.Media.DATA,
        MediaStore.Audio.Media._ID,
        MediaStore.Audio.Media.SIZE,
        MediaStore.Audio.Media.DATE_MODIFIED,
        MediaStore.Audio.Media.ALBUM,
        MediaStore.Audio.Media.ARTIST,
        MediaStore.Audio.Media.DURATION,
        MediaStore.Audio.Media.TITLE,
        MediaStore.Audio.Media.TRACK,
        MediaStore.Audio.Media.DISC_NUMBER,
        MediaStore.Audio.Media.YEAR,
    )

    // VOLUME_NAME only exists on Android 10/Q (API 29) and above; querying an
    // unknown column on older versions would fail the whole cursor.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        tmpProjection.add(MediaStore.Audio.Media.VOLUME_NAME)
    }

    return tmpProjection.toTypedArray()
}


//Query artists projection
val artistProjection = arrayOf(
    MediaStore.Audio.Artists._ID,
    MediaStore.Audio.Artists.ARTIST,
    MediaStore.Audio.Artists.NUMBER_OF_ALBUMS,
    MediaStore.Audio.Artists.NUMBER_OF_TRACKS
)

//Query genres projection
val genreProjection = arrayOf(
    MediaStore.Audio.Genres._ID,
    MediaStore.Audio.Genres.NAME
)