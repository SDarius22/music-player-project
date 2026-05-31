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

    test('does not self-evict; all registered managers stay routable', () {
      final router = ActiveChunkRouter(InMemoryChunkCacheRepository());
      final managers = List.generate(6, (i) => _FakeChunkService('song-$i'));
      for (final manager in managers) {
        router.registerManager(manager);
      }

      for (final manager in managers) {
        router.routeChunk(manager.fileHash, 1, Uint8List.fromList([9]));
      }

      for (final manager in managers) {
        expect(manager.resolved, hasLength(1));
      }
    });

    test('unregisterManager stops routing to that manager', () {
      final router = ActiveChunkRouter(InMemoryChunkCacheRepository());
      final manager = _FakeChunkService('song-1');
      router.registerManager(manager);

      router.unregisterManager(manager);
      router.routeChunk('song-1', 0, Uint8List.fromList([9]));

      expect(manager.resolved, isEmpty);
    });

    test(
      'unregisterManager only removes the matching instance, not a newer one',
      () {
        final router = ActiveChunkRouter(InMemoryChunkCacheRepository());
        final older = _FakeChunkService('song-1');
        final newer = _FakeChunkService('song-1');

        router.registerManager(older);
        router.registerManager(newer);
        router.unregisterManager(older);

        router.routeChunk('song-1', 0, Uint8List.fromList([9]));

        expect(newer.resolved, hasLength(1));
        expect(older.resolved, isEmpty);
      },
    );

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
