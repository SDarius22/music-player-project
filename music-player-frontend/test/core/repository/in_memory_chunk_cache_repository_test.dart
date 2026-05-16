import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';

void main() {
  group('InMemoryChunkCacheRepository', () {
    test('saveChunk and readChunk round-trip by file hash and index', () async {
      final repo = InMemoryChunkCacheRepository();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await repo.saveChunk('file-a', 0, bytes);

      expect(await repo.readChunk('file-a', 0), equals(bytes));
      expect(await repo.readChunk('file-a', 1), isNull);
      expect(await repo.readChunk('file-b', 0), isNull);
    });

    test('deleteChunk removes only targeted key', () async {
      final repo = InMemoryChunkCacheRepository();
      await repo.saveChunk('file-a', 0, Uint8List.fromList([1]));
      await repo.saveChunk('file-a', 1, Uint8List.fromList([2]));

      await repo.deleteChunk('file-a', 0);

      expect(await repo.readChunk('file-a', 0), isNull);
      expect(await repo.readChunk('file-a', 1), isNotNull);
    });

    test(
      'getAvailableChunkIndices returns sorted numeric indices for file',
      () async {
        final repo = InMemoryChunkCacheRepository();
        await repo.saveChunk('song', 10, Uint8List.fromList([1]));
        await repo.saveChunk('song', 2, Uint8List.fromList([1]));
        await repo.saveChunk('song', 7, Uint8List.fromList([1]));
        await repo.saveChunk('other', 1, Uint8List.fromList([1]));

        final indices = await repo.getAvailableChunkIndices('song');

        expect(indices, [2, 7, 10]);
      },
    );
  });
}
