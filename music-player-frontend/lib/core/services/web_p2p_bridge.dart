import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:web/web.dart' as web;

class WebP2PBridge {
  static final _logger = Logger('WebP2PBridge');

  final ChunkService Function(String) chunkManagerFactory;
  final Map<String, ChunkService> _managers = {};
  final Map<String, String> _songNames = {};
  final Map<String, String> _mimeByHash = {};
  String? _currentFileHash;
  late final Future<bool> _serviceWorkerReady;

  WebP2PBridge(this.chunkManagerFactory) {
    _serviceWorkerReady = _waitForServiceWorkerReady();
    _listenToServiceWorker();
  }

  Future<bool> ensureServiceWorkerReady() => _serviceWorkerReady;

  Future<bool> _waitForServiceWorkerReady() async {
    try {
      await web.window.navigator.serviceWorker.ready.toDart.timeout(
        const Duration(seconds: 8),
      );

      final controller = web.window.navigator.serviceWorker.controller;
      final controllerScript = controller?.scriptURL ?? '';
      final isP2PController = controllerScript.contains('p2p-worker.js');
      if (!isP2PController) {
        _logger.warning(
          'P2P worker is not controlling this page (controller=$controllerScript)',
        );
      }
      return isP2PController;
    } catch (e) {
      _logger.warning('Service worker readiness wait timed out or failed', e);
      return false;
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

    // Every path below must post a response or an error back to the service
    // worker. If it doesn't, the SW's pending request is never resolved and
    // sits until its 7s timeout fires, returning a `504 P2P timeout` to the
    // <audio> element (→ MediaError network failure). The two historic culprits
    // were an uncaught `loadManifest()` failure and the silent early-return on
    // a song switch — both now surface as an immediate error instead.
    try {
      final manager = _managers.putIfAbsent(
        fileHash,
        () => chunkManagerFactory(fileHash),
      );
      if (!manager.isReady) {
        await manager.loadManifest();
        if (_songNames.containsKey(fileHash)) {
          manager.configureSongInfo(
            _songNames[fileHash]!,
            ChunkStatsService.instance.reportSilently,
          );
        }
      }
      if (_currentFileHash != fileHash) {
        // Song switched away while we were loading: abandon this stale request
        // but tell the SW so it doesn't wait out the full timeout.
        _postError(msgEvent, reqId, 410, 'Song switched away from $fileHash');
        return;
      }

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

      final (responseBytes, isP2P) = await _compileBytesForRange(
        manager,
        requestedStart,
        requestedEnd,
      );

      if (_currentFileHash != fileHash) {
        _postError(msgEvent, reqId, 410, 'Song switched away from $fileHash');
        return;
      }

      final contentType = await _resolveContentType(manager, fileHash);

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
              'contentType': contentType,
            }.jsify();

        (source as web.Client).postMessage(jsResponse);
      }
    } catch (e) {
      _logger.warning('WebP2PBridge Error for file=$fileHash', e);
      _postError(msgEvent, reqId, 504, e.toString());
    }
  }

  void _postError(
    web.MessageEvent msgEvent,
    String reqId,
    int status,
    String error,
  ) {
    final source = msgEvent.source;
    if (source != null) {
      (source as web.Client).postMessage(
        {
          'type': 'P2P_CHUNK_ERROR',
          'reqId': reqId,
          'status': status,
          'error': error,
        }.jsify(),
      );
    }
  }

  void _handleStatsReport(Map<dynamic, dynamic> data) {
    final String fileHash = data['fileHash'] as String;
    final int p2pRanges = (data['p2pRanges'] as num).toInt();
    final int serverRanges = (data['serverRanges'] as num).toInt();
    final String songName =
        data['songName'] as String? ?? _songNames[fileHash] ?? 'Unknown';

    ChunkStatsService.instance.reportSilently(
      ChunkStat(
        songFileHash: fileHash,
        songName: songName,
        p2pChunks: p2pRanges,
        serverChunks: serverRanges,
      ),
    );
  }

  /// Determines the audio MIME type for [fileHash] by sniffing the magic bytes
  /// of the first chunk. Uploads can be mp3/m4a/aac/flac/ogg/opus/wav, so the
  /// service worker must report the real type rather than a hardcoded one — a
  /// wrong Content-Type pushes the browser onto a slower format-probe path.
  /// Resolved once per song and cached.
  Future<String> _resolveContentType(
    ChunkService manager,
    String fileHash,
  ) async {
    final cached = _mimeByHash[fileHash];
    if (cached != null) return cached;
    try {
      final head = await manager.getChunk(0);
      final mime = _sniffAudioMime(head);
      _mimeByHash[fileHash] = mime;
      return mime;
    } catch (e) {
      _logger.fine('Content-Type sniff failed for $fileHash: $e');
      return 'audio/mpeg';
    }
  }

  String _sniffAudioMime(Uint8List b) {
    if (b.length >= 4) {
      // 'fLaC'
      if (b[0] == 0x66 && b[1] == 0x4C && b[2] == 0x61 && b[3] == 0x43) {
        return 'audio/flac';
      }
      // 'OggS' (Ogg Vorbis / Opus)
      if (b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67 && b[3] == 0x53) {
        return 'audio/ogg';
      }
      // 'RIFF' (WAV)
      if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46) {
        return 'audio/wav';
      }
      // 'ID3' tag (MP3)
      if (b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
        return 'audio/mpeg';
      }
      // MP3 frame sync: 0xFF 0xEx/0xFx
      if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
        return 'audio/mpeg';
      }
    }
    // ISO-BMFF (m4a/aac): 'ftyp' box at offset 4
    if (b.length >= 12 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70) {
      return 'audio/mp4';
    }
    return 'audio/mpeg';
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
