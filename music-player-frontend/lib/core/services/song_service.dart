import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/sync/song_sync_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/data_sync_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';

class SongService {
  final SongRepository _songRepository;
  final ArtistRepository _artistRepository;
  final AlbumRepository _albumRepository;
  final SongRestClient _songRestService;
  final DataSyncClient _dataSyncService;

  bool _isSyncing = false;
  bool _isLibraryMetadataSyncing = false;
  DateTime? _lastLibrarySyncTime;
  static const int _chunkSize = 64 * 1024;

  SongService(
    this._songRepository,
    this._artistRepository,
    this._albumRepository,
    this._songRestService,
    this._dataSyncService,
  );

  Map<String, dynamic> get sortFields => _songRepository.sortFields;

  Stream<dynamic> get watchSongs => _songRepository.watchSongs();

  Song addSongEntity(Song song) {
    return _songRepository.saveSong(song);
  }

  int getSongCount() {
    return _songRepository.getSongCount();
  }

  Song? getLocalSong(String songPath) {
    if (songPath.isEmpty) {
      throw ArgumentError('Song path cannot be empty');
    }

    try {
      return _songRepository.getSongByPath(songPath);
    } catch (_) {
      return null;
    }
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    final local = _songRepository.getSongByFileHash(fileHash);
    if (local != null) return local;
    try {
      final serverSong = await _songRestService.getServerSong(fileHash);
      _cacheServerSongs([serverSong]);
      return _songRepository.getSongByFileHash(fileHash);
    } catch (e) {
      debugPrint('SongService: failed to fetch song $fileHash from server: $e');
      return null;
    }
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

  Future<({List<Song> content, int totalPages, int page})> getSongsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int pageSize,
  ) async {
    int? serverTotalPages;
    try {
      final serverPage = await _songRestService.getSongsPage(
        query: query,
        page: page,
        size: pageSize,
        sort: _toServerSort(sortField, ascending),
      );
      serverTotalPages = serverPage.totalPages;
      _cacheServerSongs(serverPage.content);
    } catch (e) {
      debugPrint('SongService: server fetch failed for getSongsPage: $e');
    }
    final localSongs = _songRepository.getSongsPaged(
      query,
      sortField,
      ascending,
      page * pageSize,
      pageSize,
    );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_songRepository.getSongs(query, sortField, ascending).length +
                        pageSize -
                        1) ~/
                    pageSize)
                .clamp(1, 999999);

    return (content: localSongs, totalPages: totalPages, page: page);
  }

  Future<List<Song>> getRecommendations() async {
    final page = await _songRestService.getRecommendations();
    return _cacheServerSongs(page.content);
  }

  Future<List<Song>> getForgottenFavourites() async {
    final page = await _songRestService.getForgottenFavourites();
    return _cacheServerSongs(page.content);
  }

  Future<List<Song>> getQuickDial() async {
    final page = await _songRestService.getQuickDial();
    return _cacheServerSongs(page.content);
  }

  void runSync() async {
    if (_isSyncing) return;

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
          song.fileHash = response.fileHash;
          song.requiresSync = false;
          _songRepository.updateSong(song);

          if (response.missingIndices.isNotEmpty) {
            for (final index in response.missingIndices) {
              await Future.delayed(const Duration(milliseconds: 10));
              if (index < chunks.length) {
                await _songRestService.uploadChunk(
                  fileHash: response.fileHash,
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

  Future<void> syncLibraryMetadata() async {
    if (_isLibraryMetadataSyncing) return;
    if (!_songRestService.authService.isLoggedIn) return;

    _isLibraryMetadataSyncing = true;
    try {
      final pending =
          _songRepository
              .getAllSongs()
              .where((s) => s.requiresSync && s.fileHash.isNotEmpty)
              .toList();

      if (pending.isEmpty) return;

      final changes =
          pending
              .map(
                (s) => SongSyncDto(
                  fileHash: s.fileHash,
                  playCountDelta: s.pendingPlayCountDelta,
                  likedByUser: s.likedByUser,
                  lastPlayed: s.lastPlayed,
                  totalPlayDurationSeconds: s.pendingPlayDurationSeconds,
                ),
              )
              .toList();

      final response = await _dataSyncService.syncUserLibrary(
        lastSyncTime: _lastLibrarySyncTime,
        localChanges: changes,
      );

      if (response != null) {
        _lastLibrarySyncTime = response.newSyncTime.toLocal();
        for (final s in pending) {
          s.requiresSync = false;
          s.pendingPlayCountDelta = 0;
          s.pendingPlayDurationSeconds = 0;
          _songRepository.updateSong(s);
        }
        debugPrint(
          '[SongService] Library metadata sync complete — ${pending.length} song(s) synced',
        );
      }
    } catch (e) {
      debugPrint('[SongService] Library metadata sync failed: $e');
    } finally {
      _isLibraryMetadataSyncing = false;
    }
  }

  List<Song> _cacheServerSongs(List<SongDto> serverSongs) {
    List<Song> cached = [];
    for (var serverSong in serverSongs) {
      cached.add(_cacheServerSong(serverSong));
    }
    return cached;
  }

  Song _cacheServerSong(SongDto serverSong) {
    if (serverSong.fileHash.isEmpty) {
      throw Exception('Server song must have a file hash');
    }

    var cachedSong = _songRepository.getOrCreateSongByFileHash(
      serverSong.fileHash,
    );
    cachedSong.name = serverSong.name;
    cachedSong.durationInSeconds = serverSong.durationInSeconds;
    cachedSong.trackNumber = serverSong.trackNumber;
    cachedSong.discNumber = serverSong.discNumber;
    cachedSong.year = serverSong.releaseYear;

    var artist = _artistRepository.getOrCreateArtistByServerId(
      serverSong.artist.id,
    );
    artist.name = serverSong.artist.name;
    cachedSong.artist.targetId = artist.id;
    artist.songs.add(cachedSong);
    _artistRepository.updateArtist(artist);

    var album = _albumRepository.getOrCreateAlbumByServerId(
      serverSong.album.id,
    );
    album.name = serverSong.album.name;
    cachedSong.album.targetId = album.id;
    album.songs.add(cachedSong);
    _albumRepository.updateAlbum(album);

    return _songRepository.saveSong(cachedSong);
  }

  List<List<int>> _splitIntoChunks(List<int> bytes) {
    List<List<int>> chunks = [];
    for (int i = 0; i < bytes.length; i += _chunkSize) {
      chunks.add(bytes.sublist(i, min(i + _chunkSize, bytes.length)));
    }
    return chunks;
  }

  String _toServerSort(String sortField, bool ascending) {
    final normalized = sortField.trim().toLowerCase();

    final serverField = switch (normalized) {
      'title' || 'name' => 'name',
      'year' => 'year',
      'duration' || 'durationinseconds' => 'durationInSeconds',
      'track' || 'tracknumber' => 'trackNumber',
      'disc' || 'discnumber' => 'discNumber',
      _ => 'name',
    };

    return '$serverField,${ascending ? 'asc' : 'desc'}';
  }
}
