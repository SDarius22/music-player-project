import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/negotiation_request_dto.dart';
import 'package:music_player_frontend/core/dtos/song_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';

class SongService {
  final SongRepository _songRepository;
  final SongRestService _songRestService;
  final ArtistService _artistService;
  final AlbumService _albumService;

  bool _isSyncing = false;
  static const int _chunkSize = 64 * 1024;

  SongService(
    this._songRepository,
    this._songRestService,
    this._artistService,
    this._albumService,
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
    int? serverId,
  }) async {
    if (preferServer) {
      if (serverId == null) return null;

      final cached = _songRepository.getSongByServerId(serverId);
      if (cached != null) {
        return cached;
      }

      try {
        final serverSong = await _songRestService.getServerSong(serverId);
        _cacheServerSong(serverSong);
        return _songRepository.getSongByServerId(serverId);
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

  Song? getSongByServerId(int serverId) {
    return _songRepository.getSongByServerId(serverId);
  }

  Future<Song?> fetchSongByServerId(int serverId) async {
    final local = _songRepository.getSongByServerId(serverId);
    if (local != null) return local;
    try {
      final serverSong = await _songRestService.getServerSong(serverId);
      await _cacheServerSongs([serverSong]);
      return _songRepository.getSongByServerId(serverId);
    } catch (e) {
      debugPrint('SongService: failed to fetch song $serverId from server: $e');
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

  Future<void> _cacheServerSongs(List<Song> serverSongs) async {
    final missingArtistIds =
        serverSongs
            .where(
              (s) =>
                  s.serverArtistId > 0 &&
                  _artistService.getArtistByServerId(s.serverArtistId) == null,
            )
            .map((s) => s.serverArtistId)
            .toSet();

    final missingAlbumIds =
        serverSongs
            .where(
              (s) =>
                  s.serverAlbumId > 0 &&
                  _albumService.getAlbumByServerId(s.serverAlbumId) == null,
            )
            .map((s) => s.serverAlbumId)
            .toSet();

    await Future.wait([
      ...missingArtistIds.map(
        (id) => _artistService.fetchAndCacheArtistById(id),
      ),
      ...missingAlbumIds.map((id) => _albumService.fetchAndCacheAlbumById(id)),
    ]);

    for (final s in serverSongs) {
      _cacheServerSong(s);
    }
  }

  void _cacheServerSong(Song serverSong) {
    if (serverSong.serverId <= 0) return;

    Artist? resolvedArtist;
    if (serverSong.serverArtistId > 0) {
      resolvedArtist = _artistService.getArtistByServerId(
        serverSong.serverArtistId,
      );
    }

    Album? resolvedAlbum;
    if (serverSong.serverAlbumId > 0) {
      resolvedAlbum = _albumService.getAlbumByServerId(
        serverSong.serverAlbumId,
      );
    }

    Song? existing = _songRepository.getSongByServerId(serverSong.serverId);

    if (existing == null) {
      serverSong.requiresSync = false;
      serverSong.artist.target = resolvedArtist;
      serverSong.album.target = resolvedAlbum;
      resolvedArtist?.songs.add(serverSong);
      resolvedAlbum?.songs.add(serverSong);
      if (resolvedAlbum != null) _albumService.updateAlbum(resolvedAlbum);
      if (resolvedArtist != null) _artistService.updateArtist(resolvedArtist);
      _songRepository.saveSong(serverSong);
      return;
    }

    existing.name = serverSong.name;
    existing.durationInSeconds = serverSong.durationInSeconds;
    existing.trackNumber = serverSong.trackNumber;
    existing.discNumber = serverSong.discNumber;
    existing.year = serverSong.year;
    existing.requiresSync = false;
    if (existing.serverId <= 0 && serverSong.serverId > 0) {
      existing.serverId = serverSong.serverId;
    }

    if (!existing.isLocal) {
      existing.path = '';
    }

    if (resolvedArtist != null) existing.artist.target = resolvedArtist;
    if (resolvedAlbum != null) existing.album.target = resolvedAlbum;

    if (existing.artist.target != null &&
        !existing.artist.target!.songs.contains(existing)) {
      existing.artist.target?.songs.add(existing);
      _artistService.updateArtist(existing.artist.target!);
    }
    if (existing.album.target != null &&
        !existing.album.target!.songs.contains(existing)) {
      existing.album.target?.songs.add(existing);
      _albumService.updateAlbum(existing.album.target!);
    }

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
      final cached = _songRepository.getSongByServerId(s.serverId);
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
        .map((s) => _songRepository.getSongByServerId(s.serverId) ?? s)
        .toList();
  }

  Future<List<Song>> getForgottenFavourites() async {
    final page = await _songRestService.getForgottenFavourites();
    await _cacheServerSongs(page.content);
    return page.content
        .map((s) => _songRepository.getSongByServerId(s.serverId) ?? s)
        .toList();
  }

  Future<List<Song>> getQuickDial() async {
    final page = await _songRestService.getQuickDial();
    await _cacheServerSongs(page.content);
    return page.content
        .map((s) => _songRepository.getSongByServerId(s.serverId) ?? s)
        .toList();
  }

  Widget getCoverArt(int serverId) {
    final song = _songRepository.getSongByServerId(serverId);
    final album = song?.album.target;

    return _songRestService.fetchCoverArt(
      song ?? Song()
        ..serverId = serverId,
      onBytesLoaded: (bytes) {
        if (album == null) return;
        album.imageBytes = bytes;
        _albumService.updateAlbum(album);
      },
    );
  }
}
