import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

class _FakeChunkService extends Fake implements ChunkService {
  _FakeChunkService(this._fileHash);

  final String _fileHash;
  final List<(int, Uint8List)> resolved = [];

  @override
  String get fileHash => _fileHash;

  @override
  void resolvePeerRequest(int chunkIndex, Uint8List data) {
    resolved.add((chunkIndex, data));
  }

  @override
  ValueNotifier<int> get peerStateVersionNotifier => ValueNotifier<int>(0);
}

void main() {
  group('ActiveChunkRouter', () {
    test('routes chunk to matching registered manager', () {
      final router = ActiveChunkRouter(InMemoryChunkCacheRepository());
      final manager = _FakeChunkService('song-1');
      final data = Uint8List.fromList([1, 2, 3]);
      router.registerManager(manager);

      router.routeChunk('song-1', 4, data);

      expect(manager.resolved, hasLength(1));
      expect(manager.resolved.first.$1, 4);
      expect(manager.resolved.first.$2, data);
    });

    test('drops chunks for unknown manager without throwing', () {
      final router = ActiveChunkRouter(InMemoryChunkCacheRepository());

      expect(
        () => router.routeChunk('missing-song', 0, Uint8List(0)),
        returnsNormally,
      );
    });

    test('evicts oldest manager when registry exceeds five entries', () {
      final router = ActiveChunkRouter(InMemoryChunkCacheRepository());
      final managers = List.generate(6, (i) => _FakeChunkService('song-$i'));
      for (final manager in managers) {
        router.registerManager(manager);
      }

      router.routeChunk('song-0', 1, Uint8List.fromList([9]));
      router.routeChunk('song-5', 1, Uint8List.fromList([9]));

      expect(managers.first.resolved, isEmpty);
      expect(managers.last.resolved, hasLength(1));
    });

    test('getLocalChunk delegates to cache repository', () async {
      final cache = InMemoryChunkCacheRepository();
      final router = ActiveChunkRouter(cache);
      final data = Uint8List.fromList([7, 8]);
      await cache.saveChunk('song', 3, data);

      final result = await router.getLocalChunk('song', 3);

      expect(result, equals(data));
    });
  });
}
