import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
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
      (web.Event event) async {
        final web.MessageEvent msgEvent = event as web.MessageEvent;
        final data = msgEvent.data.dartify() as Map<dynamic, dynamic>?;

        if (data != null && data['type'] == 'P2P_CHUNK_REQUEST') {
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

          int maxContentLength = 512000;
          if ((requestedEnd - requestedStart + 1) > maxContentLength) {
            requestedEnd = requestedStart + maxContentLength - 1;
          }

          if (requestedEnd >= manager.totalBytes) {
            requestedEnd = manager.totalBytes - 1;
          }

          try {
            Uint8List responseBytes = await _compileBytesForRange(
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
                  }.jsify();

              (source as web.Client).postMessage(jsResponse);
            }
          } catch (e) {
            debugPrint("WebP2PBridge Error: $e");
          }
        }
      }.toJS,
    );
  }

  Future<Uint8List> _compileBytesForRange(
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

    for (int i = startChunk; i <= endChunk && remaining > 0; i++) {
      final Uint8List chunkBytes = await manager.getChunk(i);
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

    return builder.toBytes();
  }
}
