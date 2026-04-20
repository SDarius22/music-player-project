package com.lucasjosino.on_audio_query.controllers

import android.os.Build
import androidx.annotation.RequiresApi
import com.lucasjosino.on_audio_query.PluginProvider
import com.lucasjosino.on_audio_query.consts.Method
import com.lucasjosino.on_audio_query.queries.*

class MethodController() {

    //
    @RequiresApi(Build.VERSION_CODES.Q)
    fun find() {
        when (PluginProvider.call().method) {
            //Query methods
            Method.QUERY_AUDIOS -> AudioQuery().querySongs()
            Method.QUERY_ALBUMS -> AlbumQuery().queryAlbums()
            Method.QUERY_ARTISTS -> ArtistQuery().queryArtists()
            Method.QUERY_GENRES -> GenreQuery().queryGenres()
            Method.QUERY_ARTWORK -> ArtworkQuery().queryArtwork()
            Method.QUERY_AUDIOS_FROM -> AudioFromQuery().querySongsFrom()
            Method.QUERY_WITH_FILTERS -> WithFiltersQuery().queryWithFilters()
            Method.QUERY_ALL_PATHS -> AllPathQuery().queryAllPath()
            else -> PluginProvider.result().notImplemented()
        }
    }
}