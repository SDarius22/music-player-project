import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:web/web.dart' as web;

class WebP2PBridge {
  static final _logger = Logger('WebP2PBridge');

  final ChunkService Function(String) chunkManagerFactory;
  final Map<String, ChunkService> _managers = {};
  final Map<String, String> _songNames = {};
  String? _currentFileHash;
  late final Future<void> _serviceWorkerReady;

  WebP2PBridge(this.chunkManagerFactory) {
    _serviceWorkerReady = _waitForServiceWorkerReady();
    _listenToServiceWorker();
  }

  Future<void> ensureServiceWorkerReady() => _serviceWorkerReady;

  Future<void> _waitForServiceWorkerReady() async {
    try {
      await web.window.navigator.serviceWorker.ready.toDart.timeout(
        const Duration(seconds: 8),
      );
    } catch (e) {
      _logger.warning('Service worker readiness wait timed out or failed', e);
    }
  }

  void notifySong(String fileHash, String songName) {
    _songNames[fileHash] = songName;
    _managers[fileHash]?.configureSongInfo(
      songName,
      ChunkStatsService.instance.reportSilently,
    );
  }

  void _listenToServiceWorker() {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.Event event) {
        _processWorkerMessage(event as web.MessageEvent);
      }).toJS,
    );
  }

  Future<void> _processWorkerMessage(web.MessageEvent msgEvent) async {
    final data = msgEvent.data.dartify() as Map<dynamic, dynamic>?;
    if (data == null) return;

    if (data['type'] == 'P2P_CHUNK_REQUEST') {
      await _handleChunkRequest(msgEvent, data);
    } else if (data['type'] == 'P2P_STATS_REPORT') {
      _handleStatsReport(data);
    }
  }

  Future<void> _handleChunkRequest(
    web.MessageEvent msgEvent,
    Map<dynamic, dynamic> data,
  ) async {
    final String reqId = data['reqId'] as String;
    final String fileHash = data['fileHash'] as String;
    final String rangeStr = data['range'].toString();

    _currentFileHash = fileHash;

    if (!_managers.containsKey(fileHash)) {
      _managers[fileHash] = chunkManagerFactory(fileHash);
      await _managers[fileHash]!.loadManifest();
      if (_songNames.containsKey(fileHash)) {
        _managers[fileHash]!.configureSongInfo(
          _songNames[fileHash]!,
          ChunkStatsService.instance.reportSilently,
        );
      }
    }
    if (_currentFileHash != fileHash) return;

    final manager = _managers[fileHash]!;

    int requestedStart = 0;
    int requestedEnd = manager.totalBytes - 1;

    if (rangeStr.startsWith('bytes=')) {
      final parts = rangeStr.substring(6).split('-');
      if (parts[0].isNotEmpty) {
        requestedStart = int.parse(parts[0]);
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        requestedEnd = int.parse(parts[1]);
      }
    }

    const int maxContentLength = 512000;
    if ((requestedEnd - requestedStart + 1) > maxContentLength) {
      requestedEnd = requestedStart + maxContentLength - 1;
    }

    if (requestedEnd >= manager.totalBytes) {
      requestedEnd = manager.totalBytes - 1;
    }

    if (_currentFileHash != fileHash) return;

    try {
      final (responseBytes, isP2P) = await _compileBytesForRange(
        manager,
        requestedStart,
        requestedEnd,
      );

      final source = msgEvent.source;
      if (source != null) {
        final jsResponse =
            {
              'type': 'P2P_CHUNK_RESPONSE',
              'reqId': reqId,
              'bytes': responseBytes.toJS,
              'start': requestedStart,
              'end': requestedStart + responseBytes.length - 1,
              'total': manager.totalBytes,
              'isP2P': isP2P,
              'songName': manager.songName ?? '',
            }.jsify();

        (source as web.Client).postMessage(jsResponse);
      }
    } catch (e) {
      _logger.warning('WebP2PBridge Error', e);
      final source = msgEvent.source;
      if (source != null) {
        (source as web.Client).postMessage(
          {
            'type': 'P2P_CHUNK_ERROR',
            'reqId': reqId,
            'status': 504,
            'error': e.toString(),
          }.jsify(),
        );
      }
    }
  }

  void _handleStatsReport(Map<dynamic, dynamic> data) {
    final String fileHash = data['fileHash'] as String;
    final int p2pRanges = (data['p2pRanges'] as num).toInt();
    final int serverRanges = (data['serverRanges'] as num).toInt();
    final String songName =
        data['songName'] as String? ?? _songNames[fileHash] ?? 'Unknown';

    ChunkStatsService.instance.reportSilently(
      ChunkDeliveryStats(
        fileHash: fileHash,
        songName: songName,
        p2pChunks: p2pRanges,
        serverChunks: serverRanges,
      ),
    );
  }

  Future<(Uint8List, bool)> _compileBytesForRange(
    ChunkService manager,
    int start,
    int end,
  ) async {
    final int chunkSize = manager.manifest!.chunkSize;
    final int startChunk = start ~/ chunkSize;
    final int endChunk = end ~/ chunkSize;

    final BytesBuilder builder = BytesBuilder();
    int currentOffset = start;
    int remaining = (end - start) + 1;
    bool anyP2P = false;

    for (int i = startChunk; i <= endChunk && remaining > 0; i++) {
      final Uint8List chunkBytes = await manager.getChunk(i);

      if (manager.wasServedByP2P(i) == true) anyP2P = true;

      final int chunkStartByte = i * chunkSize;

      int sliceStart = currentOffset - chunkStartByte;
      if (sliceStart < 0) sliceStart = 0;
      if (sliceStart >= chunkBytes.length) continue;

      int sliceEndEx = chunkBytes.length;
      final int wantedEndInChunk = (end + 1) - chunkStartByte;
      if (sliceEndEx > wantedEndInChunk) sliceEndEx = wantedEndInChunk;
      if (sliceEndEx > chunkBytes.length) sliceEndEx = chunkBytes.length;
      if (sliceEndEx <= sliceStart) continue;

      final int available = sliceEndEx - sliceStart;
      final int take = available > remaining ? remaining : available;
      if (take <= 0) break;

      builder.add(chunkBytes.sublist(sliceStart, sliceStart + take));
      currentOffset += take;
      remaining -= take;
    }

    return (builder.toBytes(), anyP2P);
  }
}
