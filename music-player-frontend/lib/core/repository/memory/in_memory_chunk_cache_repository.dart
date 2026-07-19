import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';

class InMemoryChunkCacheRepository implements ChunkCacheRepository {
  final Map<String, _CachedSong> _songs = {};

  _CachedSong _song(String fileHash) =>
      _songs.putIfAbsent(fileHash, _CachedSong.new);

  @override
  Future<void> configureSong(
    String fileHash,
    int chunkSize,
    int totalBytes,
    int totalChunks,
  ) async {
    final song = _song(fileHash);
    song.layout = (
      chunkSize: chunkSize,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
    );
  }

  @override
  Future<bool> finalizeSong(String fileHash) async {
    final song = _songs[fileHash];
    final layout = song?.layout;
    if (song == null || layout == null) return false;
    if (song.completed != null) return true;
    if (layout.chunkSize <= 0 ||
        layout.totalBytes <= 0 ||
        layout.totalChunks <= 0) {
      return false;
    }

    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < layout.totalChunks; index++) {
      final chunk = song.chunks[index];
      if (chunk == null) return false;
      builder.add(chunk);
    }

    final bytes = builder.takeBytes();
    if (bytes.length != layout.totalBytes ||
        sha256.convert(bytes).toString() != fileHash) {
      return false;
    }

    song.completed = bytes;
    song.chunks.clear();
    return true;
  }

  @override
  Future<Uint8List?> readChunk(String fileHash, int chunkIndex) async {
    final song = _songs[fileHash];
    if (song == null) return null;

    final completed = song.completed;
    final layout = song.layout;
    if (completed != null && layout != null) {
      if (chunkIndex < 0 || chunkIndex >= layout.totalChunks) return null;
      final offset = chunkIndex * layout.chunkSize;
      final end = (offset + layout.chunkSize).clamp(0, layout.totalBytes);
      return Uint8List.fromList(completed.sublist(offset, end));
    }

    final chunk = song.chunks[chunkIndex];
    return chunk == null ? null : Uint8List.fromList(chunk);
  }

  @override
  Future<void> saveChunk(
    String fileHash,
    int chunkIndex,
    Uint8List data,
  ) async {
    _song(fileHash).chunks[chunkIndex] = Uint8List.fromList(data);
  }

  @override
  Future<void> deleteChunk(String fileHash, int chunkIndex) async {
    final song = _songs[fileHash];
    if (song == null) return;
    song.completed = null;
    song.chunks.remove(chunkIndex);
  }

  @override
  Future<List<int>> getAvailableChunkIndices(String fileHash) async {
    final song = _songs[fileHash];
    if (song == null) return [];
    final layout = song.layout;
    if (song.completed != null && layout != null) {
      return List<int>.generate(layout.totalChunks, (index) => index);
    }
    return song.chunks.keys.toList()..sort();
  }

  @override
  Future<List<String>> getCachedFileHashes() async {
    return _songs.keys.toList();
  }
}

class _CachedSong {
  ({int chunkSize, int totalBytes, int totalChunks})? layout;
  final Map<int, Uint8List> chunks = {};
  Uint8List? completed;
}
