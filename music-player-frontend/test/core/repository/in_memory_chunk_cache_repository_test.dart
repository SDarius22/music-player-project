import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

    test('getCachedFileHashes returns unique cached song hashes', () async {
      final repo = InMemoryChunkCacheRepository();
      await repo.saveChunk('song-a', 0, Uint8List.fromList([1]));
      await repo.saveChunk('song-a', 1, Uint8List.fromList([2]));
      await repo.saveChunk('song-b', 0, Uint8List.fromList([3]));

      expect((await repo.getCachedFileHashes()).toSet(), {'song-a', 'song-b'});
    });

    test('finalization verifies completeness, length, and hash', () async {
      final repo = InMemoryChunkCacheRepository();
      final first = Uint8List.fromList([1, 2, 3, 4]);
      final second = Uint8List.fromList([5, 6, 7]);
      final fileHash = sha256.convert([...first, ...second]).toString();

      await repo.configureSong(fileHash, 4, 7, 2);
      await repo.saveChunk(fileHash, 0, first);
      expect(await repo.finalizeSong(fileHash), isFalse);
      await repo.saveChunk(fileHash, 1, second);
      expect(await repo.finalizeSong(fileHash), isTrue);
      expect(await repo.getAvailableChunkIndices(fileHash), [0, 1]);
      expect(await repo.readChunk(fileHash, 0), first);
      expect(await repo.readChunk(fileHash, 1), second);

      await repo.deleteChunk(fileHash, 0);
      expect(await repo.getAvailableChunkIndices(fileHash), isEmpty);
      expect(await repo.readChunk(fileHash, 0), isNull);
    });

    test('configured songs are enumerated before chunks arrive', () async {
      final repo = InMemoryChunkCacheRepository();
      await repo.configureSong('configured', 4, 8, 2);

      expect(await repo.getCachedFileHashes(), ['configured']);
      expect(await repo.finalizeSong('configured'), isFalse);
    });
  });
}
