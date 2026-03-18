import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:web/web.dart' as web;

class WebP2PBridge {
  final ChunkService Function(int) chunkManagerFactory;
  final Map<int, ChunkService> _managers = {};

  WebP2PBridge(this.chunkManagerFactory) {
    _listenToServiceWorker();
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
    final int songId = int.parse(data['songId'].toString());
    final String rangeStr = data['range'].toString();

    if (!_managers.containsKey(songId)) {
      _managers[songId] = chunkManagerFactory(songId);
      await _managers[songId]!.loadManifest();
    }
    final manager = _managers[songId]!;

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
      debugPrint("WebP2PBridge Error: $e");
    }
  }

  void _handleStatsReport(Map<dynamic, dynamic> data) {
    final int songId = (data['songId'] as num).toInt();
    final int p2pRanges = (data['p2pRanges'] as num).toInt();
    final int serverRanges = (data['serverRanges'] as num).toInt();
    final String songName = data['songName'] as String? ?? 'Unknown';

    ChunkStatsService.instance.report(
      ChunkDeliveryStats(
        songId: songId,
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
