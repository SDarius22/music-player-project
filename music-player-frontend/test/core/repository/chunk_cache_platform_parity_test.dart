import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/storage/io_chunk_cache_repo.dart';

void main() {
  test('web chunk cache matches native lifecycle behavior', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chunk-cache-parity-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final web = await _snapshot(InMemoryChunkCacheRepository());
    final native = await _snapshot(
      IOChunkCacheRepository(baseDirectory: directory),
    );

    expect(web.cachedBeforeChunks, native.cachedBeforeChunks);
    expect(web.incompleteFinalization, native.incompleteFinalization);
    expect(web.completeFinalization, native.completeFinalization);
    expect(web.availableAfterFinalization, native.availableAfterFinalization);
    expect(web.firstChunk, native.firstChunk);
    expect(web.lastChunk, native.lastChunk);
    expect(web.availableAfterDelete, native.availableAfterDelete);
    expect(web.readAfterDelete, native.readAfterDelete);
  });

  test(
    'web and native caches both reject a whole-file hash mismatch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chunk-cache-parity-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final wrongHash = '0' * 64;

      for (final repository in <ChunkCacheRepository>[
        InMemoryChunkCacheRepository(),
        IOChunkCacheRepository(baseDirectory: directory),
      ]) {
        await repository.configureSong(wrongHash, 4, 4, 1);
        await repository.saveChunk(wrongHash, 0, bytes);
        expect(await repository.finalizeSong(wrongHash), isFalse);
        expect(await repository.readChunk(wrongHash, 0), bytes);
      }
    },
  );
}

Future<
  ({
    List<String> cachedBeforeChunks,
    bool incompleteFinalization,
    bool completeFinalization,
    List<int> availableAfterFinalization,
    List<int>? firstChunk,
    List<int>? lastChunk,
    List<int> availableAfterDelete,
    List<int>? readAfterDelete,
  })
>
_snapshot(ChunkCacheRepository repository) async {
  final first = Uint8List.fromList([1, 2, 3, 4]);
  final last = Uint8List.fromList([5, 6, 7]);
  final fileHash = sha256.convert([...first, ...last]).toString();

  await repository.configureSong(fileHash, 4, 7, 2);
  final cachedBeforeChunks = await repository.getCachedFileHashes();
  await repository.saveChunk(fileHash, 0, first);
  final incompleteFinalization = await repository.finalizeSong(fileHash);
  await repository.saveChunk(fileHash, 1, last);
  final completeFinalization = await repository.finalizeSong(fileHash);
  final availableAfterFinalization = await repository.getAvailableChunkIndices(
    fileHash,
  );
  final firstChunk = await repository.readChunk(fileHash, 0);
  final lastChunk = await repository.readChunk(fileHash, 1);
  await repository.deleteChunk(fileHash, 0);

  return (
    cachedBeforeChunks: cachedBeforeChunks,
    incompleteFinalization: incompleteFinalization,
    completeFinalization: completeFinalization,
    availableAfterFinalization: availableAfterFinalization,
    firstChunk: firstChunk,
    lastChunk: lastChunk,
    availableAfterDelete: await repository.getAvailableChunkIndices(fileHash),
    readAfterDelete: await repository.readChunk(fileHash, 0),
  );
}
