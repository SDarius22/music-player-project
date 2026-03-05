import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ChunkCacheRepository {
  Future<Uint8List?> readChunk(int songId, int chunkIndex) async {
    final dir = await getApplicationDocumentsDirectory();
    String filePath =
        '${dir.path}/MusicPlayer${kDebugMode ? '_Debug' : ''}/song_${songId}_chunk_$chunkIndex.bin';
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> saveChunk(int songId, int chunkIndex, Uint8List data) async {
    final dir = await getApplicationDocumentsDirectory();
    String filePath =
        '${dir.path}/MusicPlayer${kDebugMode ? '_Debug' : ''}/song_${songId}_chunk_$chunkIndex.bin';
    final file = File(filePath);
    await file.writeAsBytes(data);
  }
}
