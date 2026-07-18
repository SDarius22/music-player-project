import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:path_provider/path_provider.dart';

class IOChunkCacheRepository implements ChunkCacheRepository {
  static final _logger = Logger('IOChunkCacheRepository');

  Directory? _baseDir;
  final Map<String, ({int chunkSize, int totalBytes, int totalChunks})>
  _layouts = {};

  IOChunkCacheRepository({Directory? baseDirectory}) {
    _baseDir = baseDirectory;
    if (baseDirectory == null) _getBaseDir();
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

  Future<Directory> _getSongDir(String fileHash) async {
    final base = await _getBaseDir();
    final songDir = Directory('${base.path}/${Uri.encodeComponent(fileHash)}');
    return songDir;
  }

  Future<({int chunkSize, int totalBytes, int totalChunks})?> _getLayout(
    String fileHash,
    Directory songDir,
  ) async {
    final cached = _layouts[fileHash];
    if (cached != null) return cached;
    final file = File('${songDir.path}/layout.json');
    if (!await file.exists()) return null;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final layout = (
        chunkSize: json['chunkSize'] as int,
        totalBytes: json['totalBytes'] as int,
        totalChunks: json['totalChunks'] as int,
      );
      if (layout.chunkSize <= 0 ||
          layout.totalBytes <= 0 ||
          layout.totalChunks <= 0) {
        return null;
      }
      _layouts[fileHash] = layout;
      return layout;
    } catch (e) {
      _logger.warning('Invalid cached layout for $fileHash', e);
      return null;
    }
  }

  @override
  Future<void> configureSong(
    String fileHash,
    int chunkSize,
    int totalBytes,
    int totalChunks,
  ) async {
    _layouts[fileHash] = (
      chunkSize: chunkSize,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
    );
    final songDir = await _getSongDir(fileHash);
    if (!await songDir.exists()) await songDir.create(recursive: true);
    await File('${songDir.path}/layout.json').writeAsString(
      jsonEncode({
        'chunkSize': chunkSize,
        'totalBytes': totalBytes,
        'totalChunks': totalChunks,
      }),
      flush: true,
    );
  }

  @override
  Future<Uint8List?> readChunk(String fileHash, int chunkIndex) async {
    final songDir = await _getSongDir(fileHash);
    final layout = await _getLayout(fileHash, songDir);
    final completed = File('${songDir.path}/completed.media');
    if (layout != null && await completed.exists()) {
      if (chunkIndex < 0 || chunkIndex >= layout.totalChunks) return null;
      final offset = chunkIndex * layout.chunkSize;
      final length = (layout.totalBytes - offset).clamp(0, layout.chunkSize);
      final handle = await completed.open();
      try {
        await handle.setPosition(offset);
        return await handle.read(length);
      } finally {
        await handle.close();
      }
    }
    final file = File('${songDir.path}/$chunkIndex.bin');

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> saveChunk(
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) async {
    final songDir = await _getSongDir(fileHash);

    if (!await songDir.exists()) {
      await songDir.create(recursive: true);
    }

    final file = File('${songDir.path}/$chunkIndex.bin');
    await file.writeAsBytes(data, flush: true);
  }

  @override
  Future<void> deleteChunk(String fileHash, int chunkIndex) async {
    final songDir = await _getSongDir(fileHash);
    final file = File('${songDir.path}/$chunkIndex.bin');
    try {
      final completed = File('${songDir.path}/completed.media');
      if (await completed.exists()) {
        await completed.delete();
      }
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _logger.warning('Failed to delete cached chunk $fileHash/$chunkIndex', e);
    }
  }

  @override
  Future<List<int>> getAvailableChunkIndices(String fileHash) async {
    final songDir = await _getSongDir(fileHash);

    if (!await songDir.exists()) return [];

    final layout = await _getLayout(fileHash, songDir);
    if (layout != null &&
        await File('${songDir.path}/completed.media').exists()) {
      return List<int>.generate(layout.totalChunks, (index) => index);
    }

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
      _logger.warning('Cache List Error', e);
      return [];
    }
  }

  @override
  Future<bool> finalizeSong(String fileHash) async {
    final layout = await _getLayout(fileHash, await _getSongDir(fileHash));
    if (layout == null) return false;
    final songDir = await _getSongDir(fileHash);
    final completed = File('${songDir.path}/completed.media');
    if (await completed.exists()) return true;
    final available = (await getAvailableChunkIndices(fileHash)).toSet();
    if (available.length < layout.totalChunks) return false;

    final assembling = File('${songDir.path}/completed.assembling');
    IOSink? sink;
    try {
      sink = assembling.openWrite(mode: FileMode.writeOnly);
      for (var index = 0; index < layout.totalChunks; index++) {
        final chunk = File('${songDir.path}/$index.bin');
        if (!await chunk.exists()) return false;
        await sink.addStream(chunk.openRead());
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (await assembling.length() != layout.totalBytes) return false;
      final digest = await sha256.bind(assembling.openRead()).first;
      if (digest.toString() != fileHash) {
        _logger.warning(
          'Completed cache failed final hash verification: $fileHash',
        );
        return false;
      }
      await assembling.rename(completed.path);
      for (var index = 0; index < layout.totalChunks; index++) {
        final chunk = File('${songDir.path}/$index.bin');
        if (await chunk.exists()) await chunk.delete();
      }
      return true;
    } catch (e) {
      _logger.warning('Failed to finalize cached song $fileHash', e);
      return false;
    } finally {
      await sink?.close();
      if (await assembling.exists()) await assembling.delete();
    }
  }

  @override
  Future<List<String>> getCachedFileHashes() async {
    final base = await _getBaseDir();
    if (!await base.exists()) return [];
    try {
      return await base
          .list(followLinks: false)
          .where((entity) => entity is Directory)
          .map(
            (entity) => Uri.decodeComponent(
              entity.uri.pathSegments.where((s) => s.isNotEmpty).last,
            ),
          )
          .toList();
    } catch (e) {
      _logger.warning('Failed to enumerate cached songs', e);
      return [];
    }
  }
}
