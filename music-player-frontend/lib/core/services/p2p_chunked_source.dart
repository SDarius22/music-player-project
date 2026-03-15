import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class P2PChunkedAudioSource extends StreamAudioSource {
  final int songId;
  final ChunkService Function(int) chunkManagerFactory;
  ChunkService? _chunkManager;

  P2PChunkedAudioSource({
    required this.songId,
    required this.chunkManagerFactory,
    super.tag,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    _chunkManager ??= chunkManagerFactory(songId);
    if (!_chunkManager!.isReady) {
      await _chunkManager!.loadManifest();
    }

    final manager = _chunkManager!;
    final int total = manager.totalBytes;

    if (total <= 0) {
      throw StateError('totalBytes is missing or invalid');
    }

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
        contentType: 'application/octet-stream',
      );
    }

    final int chunkSize = manager.manifest!.chunkSize;
    final int startChunk = reqStart ~/ chunkSize;
    final int endChunk = (reqEndEx - 1) ~/ chunkSize;

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: total,
      contentLength: contentLen,
      offset: reqStart,
      stream: _createByteStream(
        manager: manager,
        reqStart: reqStart,
        reqEndEx: reqEndEx,
        startChunk: startChunk,
        endChunk: endChunk,
        contentLen: contentLen,
      ),
      contentType: 'application/octet-stream',
    );
  }

  Stream<List<int>> _createByteStream({
    required ChunkService manager,
    required int reqStart,
    required int reqEndEx,
    required int startChunk,
    required int endChunk,
    required int contentLen,
  }) async* {
    final int chunkSize = manager.manifest!.chunkSize;
    int currentOffset = reqStart;
    int remaining = contentLen;

    Future<Uint8List>? nextChunkFuture;
    if (startChunk < endChunk) {
      nextChunkFuture = manager.getChunk(startChunk + 1);
    }

    for (int i = startChunk; i <= endChunk && remaining > 0; i++) {
      final Uint8List chunkBytes =
          await (i == startChunk ? manager.getChunk(i) : nextChunkFuture!);

      if (i + 1 <= endChunk) {
        nextChunkFuture = manager.getChunk(i + 1);
      }

      final int chunkStartByte = i * chunkSize;
      int sliceStart = currentOffset - chunkStartByte;
      if (sliceStart < 0) sliceStart = 0;
      if (sliceStart >= chunkBytes.length) continue;

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
