import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/p2p/p2p_chunked_source.dart';

class _FakeChunkService extends Fake implements ChunkService {
  _FakeChunkService({required this.manifest, required this.chunks});

  @override
  ChunkManifestDto? manifest;

  final Map<int, Uint8List> chunks;
  bool ready = false;
  int loadManifestCalls = 0;
  final Map<int, int> getChunkCalls = {};
  final Set<int> failOnceAt = {};

  @override
  bool get isReady => ready;

  @override
  int get totalBytes => manifest!.totalBytes;

  @override
  Future<void> loadManifest() async {
    loadManifestCalls++;
    ready = true;
  }

  @override
  Future<Uint8List> getChunk(int index) async {
    final calls = (getChunkCalls[index] ?? 0) + 1;
    getChunkCalls[index] = calls;
    if (failOnceAt.contains(index) && calls == 1) {
      throw Exception('transient');
    }
    return chunks[index]!;
  }

  @override
  ValueNotifier<int> get peerStateVersionNotifier => ValueNotifier<int>(0);
}

ChunkManifestDto _manifest(int totalBytes, {int chunkSize = 4}) {
  return ChunkManifestDto.fromJson({
    'fileHash': 'song-hash',
    'totalChunks': 3,
    'chunkSize': chunkSize,
    'totalBytes': totalBytes,
    'hashes': const ['', '', ''],
  });
}

Future<Uint8List> _collect(Stream<List<int>> stream) async {
  final data = <int>[];
  await for (final chunk in stream) {
    data.addAll(chunk);
  }
  return Uint8List.fromList(data);
}

void main() {
  group('P2PChunkedAudioSource', () {
    test('loads manifest lazily and streams requested byte range', () async {
      final manager = _FakeChunkService(
        manifest: _manifest(12),
        chunks: {
          0: Uint8List.fromList([0, 1, 2, 3]),
          1: Uint8List.fromList([4, 5, 6, 7]),
          2: Uint8List.fromList([8, 9, 10, 11]),
        },
      );

      final source = P2PChunkedAudioSource(
        fileHash: 'song-hash',
        chunkManagerFactory: (_) => manager,
      );

      final response = await source.request(2, 10);
      final bytes = await _collect(response.stream);

      expect(manager.loadManifestCalls, 1);
      expect(response.offset, 2);
      expect(response.contentLength, 8);
      expect(bytes, Uint8List.fromList([2, 3, 4, 5, 6, 7, 8, 9]));
    });

    test('retries once when getChunk throws transiently', () async {
      final manager = _FakeChunkService(
        manifest: _manifest(4),
        chunks: {
          0: Uint8List.fromList([10, 11, 12, 13]),
        },
      )..failOnceAt.add(0);

      final source = P2PChunkedAudioSource(
        fileHash: 'song-hash',
        chunkManagerFactory: (_) => manager,
      );

      final response = await source.request(0, 4);
      final bytes = await _collect(response.stream);

      expect(bytes, Uint8List.fromList([10, 11, 12, 13]));
      expect(manager.getChunkCalls[0], 2);
    });

    test(
      'open-ended request serves the full length, not a capped slice',
      () async {
        // Regression: a 2 MB response cap used to chop open-ended requests into
        // pieces. ExoPlayer (Android, API 36) then re-requested at an offset
        // past the previous response end, dropping ~100 KB of FLAC and emitting
        // a premature EOS. The source must serve contiguously to EOF.
        const chunkSize =
            750000; // 3 chunks => 2.25 MB total, above the old cap
        const total = chunkSize * 3;
        final manager = _FakeChunkService(
          manifest: _manifest(total, chunkSize: chunkSize),
          chunks: {
            0: Uint8List(chunkSize),
            1: Uint8List(chunkSize),
            2: Uint8List(chunkSize),
          },
        );

        final source = P2PChunkedAudioSource(
          fileHash: 'song-hash',
          chunkManagerFactory: (_) => manager,
        );

        final response = await source.request(0); // end == null => to EOF
        final bytes = await _collect(response.stream);

        expect(response.offset, 0);
        expect(response.contentLength, total);
        expect(bytes, hasLength(total));
      },
    );

    test('returns empty stream when range has zero length', () async {
      final manager = _FakeChunkService(
        manifest: _manifest(8),
        chunks: {
          0: Uint8List.fromList([1, 2, 3, 4]),
          1: Uint8List.fromList([5, 6, 7, 8]),
        },
      );

      final source = P2PChunkedAudioSource(
        fileHash: 'song-hash',
        chunkManagerFactory: (_) => manager,
      );

      final response = await source.request(3, 3);
      final bytes = await _collect(response.stream);

      expect(response.contentLength, 0);
      expect(bytes, isEmpty);
    });
  });
}
