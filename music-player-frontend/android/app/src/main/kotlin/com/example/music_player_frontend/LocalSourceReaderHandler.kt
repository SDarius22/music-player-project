package com.example.music_player_frontend

import android.content.ContentResolver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.system.Os
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Native bounded range reader for scoped-storage content URIs.
 *
 * Reads run on a worker thread (never the platform/UI thread), are bounded to
 * the requested length, respect asset-descriptor start offsets, and reject
 * non-seekable sources without copying or hashing the whole source. Provider
 * size/modification metadata is compared before and after the read so a
 * mutated source is reported as unstable. Every failure maps to an error
 * result; the Dart side converts those to a safe null without touching
 * persisted state. Content URIs are never opened as filesystem paths.
 */
class LocalSourceReaderHandler(
    private val contentResolver: ContentResolver,
    private val executor: ExecutorService = Executors.newSingleThreadExecutor(),
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "music_player_frontend/local_source_reader"
        private const val METHOD_READ_RANGE = "readRange"

        /** Defensive cap so a bad argument cannot force an unbounded allocation. */
        internal const val MAX_RANGE_BYTES = 1024L * 1024L

        /**
         * Bytes readable for one request: at most [requested], additionally
         * clamped to the asset-descriptor region when its length is known.
         */
        internal fun boundedLength(declaredLength: Long, offset: Long, requested: Long): Long {
            if (requested <= 0L || offset < 0L) return 0L
            if (declaredLength < 0L) return requested
            val remaining = declaredLength - offset
            return if (remaining <= 0L) 0L else minOf(requested, remaining)
        }
    }

    private class NonSeekableSourceException(message: String) : Exception(message)
    private class ShortReadException(message: String) : Exception(message)

    private data class SourceStat(val size: Long, val modifiedSeconds: Long)

    fun close() = executor.shutdownNow()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != METHOD_READ_RANGE) {
            result.notImplemented()
            return
        }
        val sourceUri = call.argument<String>("sourceUri")
        val offset = call.argument<Number>("offset")?.toLong() ?: -1L
        val length = call.argument<Number>("length")?.toLong() ?: -1L
        if (sourceUri.isNullOrBlank() || Uri.parse(sourceUri).scheme != "content" ||
            offset < 0L || length <= 0L || length > MAX_RANGE_BYTES || offset > Long.MAX_VALUE - length) {
            result.error("invalid_range", "Invalid source URI or byte range", null)
            return
        }
        executor.execute {
            val outcome = runCatching { readBounded(sourceUri, offset, length) }
            mainHandler.post {
                outcome.fold(
                    onSuccess = { payload -> result.success(payload) },
                    onFailure = { error ->
                        when (error) {
                            is SecurityException ->
                                result.error("permission_denied", "Read not permitted", null)
                            is NonSeekableSourceException ->
                                result.error("not_seekable", "Source is not seekable", null)
                            is ShortReadException ->
                                result.error("short_read", "Source ended before the range", null)
                            else ->
                                result.error("unavailable", "Source unavailable", null)
                        }
                    },
                )
            }
        }
    }

    private fun readBounded(sourceUri: String, offset: Long, requested: Long): Map<String, Any?> {
        val uri = Uri.parse(sourceUri)
        val before = queryStat(uri)
        // Throws SecurityException when the read permission is gone and
        // FileNotFoundException when the provider no longer has the item.
        val descriptor = contentResolver.openAssetFileDescriptor(uri, "r")
            ?: throw IOException("Source could not be opened")
        descriptor.use { asset ->
            val effective = boundedLength(asset.declaredLength, offset, requested)
            if (effective != requested) throw ShortReadException("Range exceeds source length")
            if (asset.startOffset > Long.MAX_VALUE - offset - requested) {
                throw IOException("Invalid descriptor offset")
            }
            val buffer = ByteArray(effective.toInt())
            var readTotal = 0
            // pread respects the descriptor region without sharing seek position
            // or creating a second Java owner of the same file descriptor.
            while (readTotal < buffer.size) {
                val read = try {
                    Os.pread(asset.fileDescriptor, buffer, readTotal, buffer.size - readTotal,
                        asset.startOffset + offset + readTotal)
                } catch (error: android.system.ErrnoException) {
                    throw NonSeekableSourceException("Source does not support positioned reads")
                }
                if (read <= 0) break
                readTotal += read
            }
            // Requested ranges are manifest-derived, so a short read means the
            // source no longer matches its manifest: reject, never pad.
            if (readTotal != buffer.size) {
                throw ShortReadException("Source ended at $readTotal of ${buffer.size} bytes")
            }
            val after = queryStat(uri)
            val stable = before != null && before == after
            return mapOf(
                "bytes" to buffer,
                "size" to before?.size,
                "modifiedAtMs" to before?.let { it.modifiedSeconds * 1000L },
                "sourceStable" to stable,
            )
        }
    }

    private fun queryStat(uri: Uri): SourceStat? {
        return try {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.DATE_MODIFIED),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                val size = if (cursor.isNull(0)) -1L else cursor.getLong(0)
                val modified = if (cursor.isNull(1)) -1L else cursor.getLong(1)
                if (size < 0L || modified < 0L) return@use null
                SourceStat(size, modified)
            }
        } catch (error: Exception) {
            // Providers without query support cannot prove stability.
            null
        }
    }
}

/** Engine-owned so background audio retains its reader after activity teardown. */
class LocalSourceReaderPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var reader: LocalSourceReaderHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        reader = LocalSourceReaderHandler(binding.applicationContext.contentResolver)
        channel = MethodChannel(binding.binaryMessenger, LocalSourceReaderHandler.CHANNEL_NAME)
        channel?.setMethodCallHandler(reader)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        reader?.close()
        reader = null
        channel = null
    }
}
