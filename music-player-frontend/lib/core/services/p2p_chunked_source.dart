import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class P2PChunkedAudioSource extends StreamAudioSource {
  final ChunkService chunkManager;

  P2PChunkedAudioSource({required this.chunkManager, super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int total = chunkManager.totalBytes;
    if (total <= 0) {
      throw StateError('totalBytes is missing or invalid');
    }
    if (chunkManager.manifest == null) {
      await chunkManager.loadManifest();
    }

    // Treat end as exclusive to match just_audio proxy range behavior.
    final int reqStart = (start ?? 0).clamp(0, total);
    final int reqEndEx = (end ?? total).clamp(reqStart, total);
    final int contentLen = reqEndEx - reqStart;

    if (contentLen == 0) {
      return StreamAudioResponse(
        rangeRequestsSupported: true,
        sourceLength: total,
        contentLength: 0,
        offset: reqStart,
        stream: const Stream.empty(),
        contentType: 'audio/flac',
      );
    }

    final int chunkSize = chunkManager.manifest!.chunkSize;

    // Chunk indexes are floor-based.
    final int startChunk = reqStart ~/ chunkSize;
    final int endChunk = (reqEndEx - 1) ~/ chunkSize;

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: total,
      contentLength: contentLen,
      offset: reqStart,
      stream: _createByteStream(
        reqStart: reqStart,
        reqEndEx: reqEndEx,
        startChunk: startChunk,
        endChunk: endChunk,
        contentLen: contentLen,
      ),
      contentType: 'audio/flac',
    );
  }

  Stream<List<int>> _createByteStream({
    required int reqStart,
    required int reqEndEx,
    required int startChunk,
    required int endChunk,
    required int contentLen,
  }) async* {
    final int chunkSize = chunkManager.manifest!.chunkSize;

    int currentOffset = reqStart;
    int remaining = contentLen;

    Future<Uint8List>? nextChunkFuture;
    if (startChunk < endChunk) {
      nextChunkFuture = chunkManager.getChunk(startChunk + 1);
    }

    for (int i = startChunk; i <= endChunk && remaining > 0; i++) {
      final Uint8List chunkBytes =
          await (i == startChunk ? chunkManager.getChunk(i) : nextChunkFuture!);

      if (i + 1 <= endChunk) {
        nextChunkFuture = chunkManager.getChunk(i + 1);
      }

      final int chunkStartByte = i * chunkSize;

      int sliceStart = currentOffset - chunkStartByte;
      if (sliceStart < 0) sliceStart = 0;
      if (sliceStart >= chunkBytes.length) continue;

      // End limit within this chunk (exclusive).
      int sliceEndEx = chunkBytes.length;
      final int wantedEndInChunk = reqEndEx - chunkStartByte;
      if (sliceEndEx > wantedEndInChunk) sliceEndEx = wantedEndInChunk;
      if (sliceEndEx > chunkBytes.length) sliceEndEx = chunkBytes.length;
      if (sliceEndEx <= sliceStart) continue;

      final int available = sliceEndEx - sliceStart;
      final int take = available > remaining ? remaining : available;
      if (take <= 0) break;

      yield chunkBytes.sublist(sliceStart, sliceStart + take);

      currentOffset += take;
      remaining -= take;
    }
  }
}
