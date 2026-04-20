package com.lucasjosino.on_audio_query.queries

import android.content.ContentResolver
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lucasjosino.on_audio_query.PluginProvider
import com.lucasjosino.on_audio_query.queries.helper.QueryHelper
import com.lucasjosino.on_audio_query.types.checkAudiosUriType
import com.lucasjosino.on_audio_query.types.sorttypes.checkSongSortType
import com.lucasjosino.on_audio_query.utils.songProjection
import io.flutter.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** OnAudiosQuery */
class AudioQuery : ViewModel() {

    companion object {
        private const val TAG = "OnAudiosQuery"
    }

    // Main parameters
    private val helper = QueryHelper()
    private var selection: String? = null

    private lateinit var uri: Uri
    private lateinit var sortType: String
    private lateinit var resolver: ContentResolver

    /**
     * Method to "query" all songs.
     */
    fun querySongs() {
        val call = PluginProvider.call()
        val result = PluginProvider.result()
        val context = PluginProvider.context()
        this.resolver = context.contentResolver

        // Sort: Type and Order.
        sortType = checkSongSortType(
            call.argument<Int>("sortType"),
            call.argument<Int>("orderType")!!,
            call.argument<Boolean>("ignoreCase")!!
        )

        // Check uri:
        //   * 0 -> External.
        //   * 1 -> Internal.
        uri = checkAudiosUriType(call.argument<Int>("uri")!!)

        // Cache projection once; reuse for both selection building and the query.
        val projection = songProjection()

        // Here we provide a custom 'path'.
        call.argument<String>("path")?.let { path ->
            selection = "${projection[0]} like '%$path/%'"
        }

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tsortType: $sortType")
        Log.d(TAG, "\tselection: $selection")
        Log.d(TAG, "\turi: $uri")

        // Query everything in background for a better performance.
        viewModelScope.launch {
            val queryResult = loadSongs(projection)
            result.success(queryResult)
        }
    }

    //Loading in Background
    private suspend fun loadSongs(projection: Array<String>): ArrayList<MutableMap<String, Any?>> =
        withContext(Dispatchers.IO) {
            val cursor = resolver.query(uri, projection, selection, null, sortType)
                ?: return@withContext ArrayList()

            Log.d(TAG, "Cursor count: ${cursor.count}")

            // Pre-size list and cache column indices to avoid per-row index lookups.
            val songList = ArrayList<MutableMap<String, Any?>>(cursor.count)
            val columnIndices = projection.associateWith { cursor.getColumnIndex(it) }

            cursor.use {
                while (it.moveToNext()) {
                    val tempData: MutableMap<String, Any?> = HashMap(projection.size)

                    for ((col, idx) in columnIndices) {
                        tempData[col] = helper.loadSongItem(col, idx, it)
                    }

                    // Merge extra info (file_hash, etc.) directly into tempData.
                    helper.loadSongExtraInfo(tempData)

                    songList.add(tempData)
                }
            }

            return@withContext songList
        }
}
