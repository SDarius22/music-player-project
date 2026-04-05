import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/song_page_dto.dart';
import 'package:music_player_frontend/core/dtos/song_sync_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/data_sync_rest_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';

class SongService {
  final SongRepository _songRepository;
  final SongRestService _songRestService;
  final ArtistService _artistService;
  final AlbumService _albumService;
  final DataSyncService _dataSyncService;

  bool _isSyncing = false;
  bool _isLibraryMetadataSyncing = false;
  DateTime? _lastLibrarySyncTime;
  static const int _chunkSize = 64 * 1024;

  SongService(
    this._songRepository,
    this._songRestService,
    this._artistService,
    this._albumService,
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

  Future<List<Song>> getAllSongs() async {
    try {
      final serverSongs = await _songRestService.getAllSongs();
      await _cacheServerSongs(serverSongs);
    } catch (e) {
      debugPrint('SongService: server fetch failed for getAllSongs: $e');
    }
    return _songRepository.getAllSongs();
  }

  Future<List<Song>> getSongs(
    String query,
    String sortField,
    bool ascending,
  ) async {
    try {
      await searchSongsFromServer(
        query,
        page: 0,
        size: 200,
        sort: _toServerSort(sortField, ascending),
      );
    } catch (e) {
      debugPrint('SongService: server fetch failed for getSongs: $e');
    }
    return _songRepository.getSongs(query, sortField, ascending);
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

  Future<Song?> getSong(
    String songPath, {
    bool preferServer = false,
    String? fileHash,
  }) async {
    if (preferServer) {
      if (fileHash == null || fileHash.isEmpty) return null;

      final cached = _songRepository.getSongByFileHash(fileHash);
      if (cached != null) {
        return cached;
      }

      try {
        final serverSong = await _songRestService.getServerSong(fileHash);
        _cacheServerSong(serverSong);
        return _songRepository.getSongByFileHash(fileHash);
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

  Future<List<Song>> refreshServerSongs() async {
    final serverSongs = await _songRestService.getAllSongs();
    await _cacheServerSongs(serverSongs);
    return _songRepository.getAllSongs();
  }

  Future<List<Song>> getServerSongs() async {
    return await refreshServerSongs();
  }

  Song? getSongByFileHash(String fileHash) {
    return _songRepository.getSongByFileHash(fileHash);
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    final local = _songRepository.getSongByFileHash(fileHash);
    if (local != null) return local;
    try {
      final serverSong = await _songRestService.getServerSong(fileHash);
      await _cacheServerSongs([serverSong]);
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

  void recordPlay(int songId) {
    final song = _songRepository.getSong(songId);
    song.playCount++;
    song.lastPlayed = DateTime.now();
    song.requiresSync = true;
    _songRepository.updateSong(song);
  }

  Future<void> _cacheServerSongs(List<Song> serverSongs) async {
    for (final s in serverSongs) {
      if (s.artist.target != null && s.artist.target!.serverId > 0) {
        final existing = _artistService.getArtistByServerId(
          s.artist.target!.serverId,
        );
        if (existing == null) {
          _artistService.cacheServerArtist(s.artist.target!);
        }
      }
      if (s.album.target != null && s.album.target!.serverId > 0) {
        if (s.artist.target != null && s.artist.target!.serverId > 0) {
          final savedArtist = _artistService.getArtistByServerId(
            s.artist.target!.serverId,
          );
          if (savedArtist != null) {
            s.album.target!.artist.target = savedArtist;
          }
        }
        final existing = _albumService.getAlbumByServerId(
          s.album.target!.serverId,
        );
        if (existing == null) {
          _albumService.cacheServerAlbum(s.album.target!);
        }
      }
    }

    for (final s in serverSongs) {
      _cacheServerSong(s);
    }
  }

  void _cacheServerSong(Song serverSong) {
    if (serverSong.fileHash.isEmpty) return;

    Artist? resolvedArtist =
        serverSong.artist.target != null
            ? _artistService.getArtistByServerId(
                  serverSong.artist.target!.serverId,
                ) ??
                serverSong.artist.target
            : null;

    Album? resolvedAlbum =
        serverSong.album.target != null
            ? _albumService.getAlbumByServerId(
                  serverSong.album.target!.serverId,
                ) ??
                serverSong.album.target
            : null;

    Song? existing = _songRepository.getSongByFileHash(serverSong.fileHash);

    if (existing == null) {
      serverSong.requiresSync = false;
      serverSong.artist.target = resolvedArtist;
      serverSong.album.target = resolvedAlbum;
      _songRepository.saveSong(serverSong);
      return;
    }

    existing.name = serverSong.name;
    existing.durationInSeconds = serverSong.durationInSeconds;
    existing.trackNumber = serverSong.trackNumber;
    existing.discNumber = serverSong.discNumber;
    existing.year = serverSong.year;
    existing.requiresSync = false;

    if (!existing.isLocal) {
      existing.path = '';
    }

    if (resolvedArtist != null) existing.artist.target = resolvedArtist;
    if (resolvedAlbum != null) existing.album.target = resolvedAlbum;

    _songRepository.updateSong(existing);
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

  List<List<int>> _splitIntoChunks(List<int> bytes) {
    List<List<int>> chunks = [];
    for (int i = 0; i < bytes.length; i += _chunkSize) {
      chunks.add(bytes.sublist(i, min(i + _chunkSize, bytes.length)));
    }
    return chunks;
  }

  Future<SongPageDto> getSongsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int pageSize,
  ) async {
    try {
      final serverPage = await _songRestService.getSongsPage(
        query: query,
        page: page,
        size: pageSize,
        sort: _toServerSort(sortField, ascending),
      );
      await _cacheServerSongs(serverPage.content);
      if (serverPage.totalElements > 0) {
        final content = _songRepository.getSongsPaged(
          query,
          sortField,
          ascending,
          page * pageSize,
          pageSize,
        );
        return SongPageDto(
          content: content,
          page: page,
          size: pageSize,
          totalPages: serverPage.totalPages,
          totalElements: serverPage.totalElements,
        );
      }
    } catch (e) {
      debugPrint('SongService: server fetch failed for getSongsPage: $e');
    }
    final localAll = _songRepository.getSongs(query, sortField, ascending);
    final totalElements = localAll.length;
    final totalPages =
        totalElements == 0 ? 1 : (totalElements / pageSize).ceil();
    final content = _songRepository.getSongsPaged(
      query,
      sortField,
      ascending,
      page * pageSize,
      pageSize,
    );
    return SongPageDto(
      content: content,
      page: page,
      size: pageSize,
      totalPages: totalPages,
      totalElements: totalElements,
    );
  }

  List<Song> getSongsPagedLocal(
    String query,
    String sortField,
    bool ascending,
    int page,
    int pageSize,
  ) {
    return _songRepository.getSongsPaged(
      query,
      sortField,
      ascending,
      page * pageSize,
      pageSize,
    );
  }

  Future<List<Song>> searchSongsFromServer(
    String query, {
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    final result = await searchSongsPageFromServer(
      query,
      page: page,
      size: size,
      sort: sort,
    );
    return result.content;
  }

  Future<SongPageDto> searchSongsPageFromServer(
    String query, {
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    final serverPage = await _songRestService.getSongsPage(
      query: query,
      page: page,
      size: size,
      sort: sort,
    );

    await _cacheServerSongs(serverPage.content);

    final refreshed = <Song>[];
    for (final s in serverPage.content) {
      final cached = _songRepository.getSongByFileHash(s.fileHash);
      if (cached != null) {
        refreshed.add(cached);
      } else {
        refreshed.add(s);
      }
    }

    return SongPageDto(
      content: refreshed,
      page: serverPage.page,
      size: serverPage.size,
      totalPages: serverPage.totalPages,
      totalElements: serverPage.totalElements,
    );
  }

  Future<List<Song>> getRecommendations() async {
    final page = await _songRestService.getRecommendations();
    await _cacheServerSongs(page.content);
    return page.content
        .map((s) => _songRepository.getSongByFileHash(s.fileHash) ?? s)
        .toList();
  }

  Future<List<Song>> getForgottenFavourites() async {
    final page = await _songRestService.getForgottenFavourites();
    await _cacheServerSongs(page.content);
    return page.content
        .map((s) => _songRepository.getSongByFileHash(s.fileHash) ?? s)
        .toList();
  }

  Future<List<Song>> getQuickDial() async {
    final page = await _songRestService.getQuickDial();
    await _cacheServerSongs(page.content);
    return page.content
        .map((s) => _songRepository.getSongByFileHash(s.fileHash) ?? s)
        .toList();
  }
}
