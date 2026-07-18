import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/storage/io_chunk_cache_repo.dart';

void main() {
  test('verified chunks are promoted into one completed media file', () async {
    final directory = await Directory.systemTemp.createTemp('chunk-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final first = Uint8List.fromList([1, 2, 3, 4]);
    final second = Uint8List.fromList([5, 6, 7]);
    final allBytes = [...first, ...second];
    final fileHash = sha256.convert(allBytes).toString();
    final repository = IOChunkCacheRepository(baseDirectory: directory);

    await repository.configureSong(fileHash, 4, 7, 2);
    await repository.saveChunk(fileHash, 0, first);
    await repository.saveChunk(fileHash, 1, second);

    expect(await repository.finalizeSong(fileHash), isTrue);
    expect(await repository.getAvailableChunkIndices(fileHash), [0, 1]);
    expect(await repository.readChunk(fileHash, 0), first);
    expect(await repository.readChunk(fileHash, 1), second);

    final songDirectory = Directory(
      '${directory.path}/${Uri.encodeComponent(fileHash)}',
    );
    expect(
      await File('${songDirectory.path}/completed.media').exists(),
      isTrue,
    );
    expect(await File('${songDirectory.path}/0.bin').exists(), isFalse);
    expect(await File('${songDirectory.path}/1.bin').exists(), isFalse);
  });

  test('final promotion refuses a whole-file hash mismatch', () async {
    final directory = await Directory.systemTemp.createTemp('chunk-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = IOChunkCacheRepository(baseDirectory: directory);
    final wrongHash = '0' * 64;

    await repository.configureSong(wrongHash, 4, 4, 1);
    await repository.saveChunk(wrongHash, 0, Uint8List.fromList([1, 2, 3, 4]));

    expect(await repository.finalizeSong(wrongHash), isFalse);
    expect(await repository.readChunk(wrongHash, 0), [1, 2, 3, 4]);
  });
}
