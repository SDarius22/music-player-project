import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:path_provider/path_provider.dart';

class IOChunkCacheRepository implements ChunkCacheRepository {
  Directory? _baseDir;

  IOChunkCacheRepository() {
    _getBaseDir();
  }

  Future<Directory> _getBaseDir() async {
    if (_baseDir != null && _baseDir!.existsSync()) return _baseDir!;

    final dir = await getApplicationDocumentsDirectory();
    _baseDir = Directory(
      '${dir.path}/MusicPlayer${kDebugMode ? '_Debug' : ''}/chunks',
    );

    if (!await _baseDir!.exists()) {
      await _baseDir!.create(recursive: true);
    }
    return _baseDir!;
  }

  Future<Directory> _getSongDir(int songId) async {
    final base = await _getBaseDir();
    final songDir = Directory('${base.path}/$songId');
    return songDir;
  }

  @override
  Future<Uint8List?> readChunk(int songId, int chunkIndex) async {
    final songDir = await _getSongDir(songId);
    final file = File('${songDir.path}/$chunkIndex.bin');

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> saveChunk(int songId, int chunkIndex, Uint8List data) async {
    final songDir = await _getSongDir(songId);

    if (!await songDir.exists()) {
      await songDir.create(recursive: true);
    }

    final file = File('${songDir.path}/$chunkIndex.bin');
    await file.writeAsBytes(data, flush: true);
  }

  @override
  Future<List<int>> getAvailableChunkIndices(int songId) async {
    final songDir = await _getSongDir(songId);

    if (!await songDir.exists()) return [];

    try {
      return songDir
          .listSync(recursive: false)
          .whereType<File>()
          .map((file) {
            final name = file.uri.pathSegments.last;
            if (name.endsWith('.bin')) {
              return int.tryParse(name.replaceAll('.bin', ''));
            }
            return null;
          })
          .whereType<int>()
          .toList();
    } catch (e) {
      debugPrint("Cache List Error: $e");
      return [];
    }
  }
}
