import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';

class SongService {
  final SongRepository _songRepository;
  final SongRestService _songRestService;

  bool _isSyncing = false;
  static const int _chunkSize = 64 * 1024; // 64KB

  SongService(this._songRepository, this._songRestService);

  Map<String, dynamic> get sortFields => _songRepository.sortFields;

  Stream<dynamic> get watchSongs => _songRepository.watchSongs();

  Song addSongEntity(Song song) {
    return _songRepository.saveSong(song);
  }

  int getSongCount() {
    return _songRepository.getSongCount();
  }

  List<Song> addSongsEntitiesBatch(List<Song> songs) {
    debugPrint("Adding batch of ${songs.length} songs to the database");
    return _songRepository.saveSongs(songs);
  }

  void addSongsBatch(List<Song> songs) {
    for (var song in songs) {
      _songRepository.saveSong(song);
    }
  }

  Song? getSongContaining(String query) {
    return _songRepository.getSongContaining(query);
  }

  Future<List<Song>> getAllSongs({
    bool preferServer = false,
    bool fallbackToServer = false,
  }) async {
    if (preferServer) {
      return await _songRestService.getAllSongs();
    }

    final local = _songRepository.getAllSongs();
    if (fallbackToServer && local.isEmpty) {
      return await _songRestService.getAllSongs();
    }
    return local;
  }

  Future<List<Song>> getSongs(
    String query,
    String sortField,
    bool ascending, {
    bool preferServer = false,
    bool fallbackToServer = false,
  }) async {
    if (!preferServer) {
      final local = _songRepository.getSongs(query, sortField, ascending);
      if (fallbackToServer && local.isEmpty) {
        final serverSongs = await _songRestService.getAllSongs();
        return serverSongs;
      }
      return local;
    }

    final serverSongs = await _songRestService.getAllSongs();
    return serverSongs;
  }

  Future<Song?> getSong(
    String songPath, {
    bool preferServer = false,
    int? serverId,
  }) async {
    if (preferServer) {
      if (serverId == null) return null;
      try {
        return await _songRestService.getServerSong(serverId);
      } catch (_) {
        return null;
      }
    }

    if (songPath.isEmpty) {
      throw ArgumentError('Song path cannot be empty');
    }

    try {
      return _songRepository.getSongByPath(songPath);
    } catch (_) {
      return null;
    }
  }

  Future<List<Song>> getServerSongs() async {
    return await _songRestService.getAllSongs();
  }

  void updateSong(Song song) {
    _songRepository.updateSong(song);
  }

  void updateSongsBatch(List<Song> songs) {
    _songRepository.updateSongs(songs);
  }

  void deleteSong(Song song) {
    _songRepository.deleteSong(song);
  }

  Future<List<Song>> getSongsFromPaths(List<String> paths) async {
    if (paths.isEmpty) {
      return [];
    }
    List<Song> songs = [];
    for (String path in paths) {
      final song = await getSong(path);
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
  }

  void linkToServerId(int localId, int serverId) {
    final song = _songRepository.getSong(localId);
    song.serverId = serverId;
    _songRepository.updateSong(song);
  }

  void recordPlay(int songId) {
    final song = _songRepository.getSong(songId);
    song.playCount++;
    song.lastPlayed = DateTime.now();
    song.requiresSync = true;
    _songRepository.updateSong(song);
  }

  void runSync() async {
    if (_isSyncing) return;

    // Web guard.
    if (kIsWeb) {
      debugPrint('Song sync is not supported on web; skipping.');
      return;
    }

    _isSyncing = true;

    if (!_songRestService.authService.isLoggedIn) {
      debugPrint('User not logged in, skipping song sync');
      _isSyncing = false;
      return;
    }

    debugPrint('Starting song sync...');

    try {
      final unsyncedSongs = _songRepository.getUnsyncedSongs();

      if (unsyncedSongs.isEmpty) {
        debugPrint('No songs to sync');
        _isSyncing = false;
        return;
      }

      for (int i = 0; i < unsyncedSongs.length; i++) {
        await Future.delayed(const Duration(milliseconds: 50));

        final song = unsyncedSongs[i];
        final file = File(song.path);

        if (!await file.exists()) continue;

        final fileBytes = await file.readAsBytes();
        final fileHash = sha256.convert(fileBytes).toString();
        final chunks = _splitIntoChunks(fileBytes);
        final hashes = chunks.map((c) => sha256.convert(c).toString()).toList();

        String photoBase64 = "";
        final coverBytes = song.album.target?.imageBytes;
        if (coverBytes != null && coverBytes.isNotEmpty) {
          photoBase64 = base64Encode(coverBytes);
        }

        final request = NegotiationRequestDto(
          name: song.name,
          artistName: song.artist.target?.name ?? 'Unknown Artist',
          albumName: song.album.target?.name ?? 'Unknown Album',
          photoBase64: photoBase64,
          durationInSeconds: song.durationInSeconds,
          trackNumber: song.trackNumber,
          discNumber: song.discNumber,
          year: song.year,
          hashes: hashes,
          fileHash: fileHash,
        );

        final response = await _songRestService.negotiateUpload(request);

        if (response != null) {
          song.serverId = response.songId;
          song.requiresSync = false;
          _songRepository.updateSong(song);

          if (response.missingIndices.isNotEmpty) {
            for (final index in response.missingIndices) {
              await Future.delayed(const Duration(milliseconds: 10));
              if (index < chunks.length) {
                await _songRestService.uploadChunk(
                  songId: response.songId,
                  chunkIndex: index,
                  chunkBytes: chunks[index],
                  hash: hashes[index],
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  List<List<int>> _splitIntoChunks(List<int> bytes) {
    List<List<int>> chunks = [];
    for (int i = 0; i < bytes.length; i += _chunkSize) {
      chunks.add(bytes.sublist(i, min(i + _chunkSize, bytes.length)));
    }
    return chunks;
  }
}
