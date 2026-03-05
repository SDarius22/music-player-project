import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class P2PChunkedAudioSource extends StreamAudioSource {
  final ChunkService chunkManager;

  P2PChunkedAudioSource({required this.chunkManager, super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int requestStart = start ?? 0;
    final int requestEnd = end ?? (chunkManager.totalBytes - 1);
    final int requestLength = (requestEnd - requestStart) + 1;

    final int startChunk = requestStart ~/ chunkManager.manifest!.chunkSize;
    final int endChunk = requestEnd ~/ chunkManager.manifest!.chunkSize;

    return StreamAudioResponse(
      sourceLength: chunkManager.totalBytes,
      contentLength: requestLength,
      offset: requestStart,
      stream: _createByteStream(requestStart, requestEnd, startChunk, endChunk),
      contentType: 'audio/mpeg',
    );
  }

  Stream<List<int>> _createByteStream(
    int reqStart,
    int reqEnd,
    int startChunk,
    int endChunk,
  ) async* {
    int currentOffset = reqStart;

    // PRE-FETCHING: Start downloading the very next chunk immediately in the background
    Future<Uint8List>? nextChunkFuture;
    if (startChunk < endChunk) {
      nextChunkFuture = chunkManager.getChunk(startChunk + 1);
    }

    for (int i = startChunk; i <= endChunk; i++) {
      // If it's the first loop, fetch normally. Otherwise, await the background future we already started.
      final chunkBytes =
          await (i == startChunk ? chunkManager.getChunk(i) : nextChunkFuture!);

      // PRE-FETCHING: While we are busy yielding the current chunk to the audio player,
      // fire off the request for the *next* chunk so it's ready for the next loop iteration.
      if (i + 1 <= endChunk) {
        nextChunkFuture = chunkManager.getChunk(i + 1);
      }

      int chunkStartByte = i * chunkManager.manifest!.chunkSize;
      int sliceStart =
          (currentOffset > chunkStartByte)
              ? (currentOffset - chunkStartByte)
              : 0;
      int sliceEnd = chunkBytes.length;

      if (i == endChunk) {
        int overflow = (chunkStartByte + chunkBytes.length) - (reqEnd + 1);
        if (overflow > 0) sliceEnd -= overflow;
      }

      final slicedBytes = chunkBytes.sublist(sliceStart, sliceEnd);

      // Yield the bytes to the native player
      yield slicedBytes;

      currentOffset += slicedBytes.length;
    }
  }
}
