import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class P2PChunkedAudioSource extends StreamAudioSource {
  static final _logger = Logger('P2PChunkedAudioSource');

  final String fileHash;
  final ChunkService Function(String) chunkManagerFactory;
  ChunkService? _chunkManager;

  P2PChunkedAudioSource({
    required this.fileHash,
    required this.chunkManagerFactory,
    super.tag,
  });

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    _chunkManager ??= chunkManagerFactory(fileHash);
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
      nextChunkFuture = _getChunkWithRetry(manager, startChunk + 1);
    }

    for (int i = startChunk; i <= endChunk && remaining > 0; i++) {
      final Uint8List chunkBytes =
          await (i == startChunk
              ? _getChunkWithRetry(manager, i)
              : nextChunkFuture!);

      if (i + 1 <= endChunk) {
        nextChunkFuture = _getChunkWithRetry(manager, i + 1);
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

  static const int _maxChunkAttempts = 4;

  Future<Uint8List> _getChunkWithRetry(ChunkService manager, int index) async {
    Object? lastError;
    for (int attempt = 1; attempt <= _maxChunkAttempts; attempt++) {
      try {
        return await manager.getChunk(index);
      } catch (e) {
        lastError = e;
        _logger.warning(
          'getChunk failed for file=$fileHash idx=$index '
          '(attempt $attempt/$_maxChunkAttempts): $e',
        );
        if (attempt < _maxChunkAttempts) {
          await Future.delayed(Duration(milliseconds: 150 * attempt));
        }
      }
    }
    // Exhausted retries: rethrow so the response surfaces the failure rather
    // than silently delivering a short read.
    throw Exception('getChunk exhausted retries for idx=$index: $lastError');
  }
}
