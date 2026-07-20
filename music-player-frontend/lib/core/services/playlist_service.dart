import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_song_position_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class PlaylistService {
  static final _logger = Logger('PlaylistService');

  final PlaylistRepository _playlistRepository;
  final SongRepository _songRepository;
  final SongService _songService;
  final PlaylistRestClient _playlistRestService;

  PlaylistService(
    this._playlistRepository,
    this._playlistRestService,
    this._songRepository,
    this._songService,
  );

  Map<String, dynamic> get sortFields => _playlistRepository.sortFields;

  Future<Playlist> addPlaylist(
    String name,
    List<Song> songs,
    Uint8List? coverArt,
  ) async {
    Playlist newPlaylist = Playlist(name, songs: songs);
    newPlaylist.imageBytes = coverArt;

    final coverBase64 = coverArt != null ? base64Encode(coverArt) : null;
    final request = CreatePlaylistDto(
      name: name,
      playlistSongs: _toServerSongPositions(songs),
      coverImageBase64: coverBase64,
    );
    final result = await _playlistRestService.createPlaylist(request);
    if (result == null || result.id <= 0) {
      throw StateError('The playlist could not be created in the cloud');
    }
    newPlaylist.serverId = result.id;

    return _playlistRepository.savePlaylist(newPlaylist);
  }

  Future<Playlist> updatePlaylist(Playlist playlist) async {
    if (playlist.serverId > 0) {
      final request = UpdatePlaylistDto(
        name: playlist.getName(),
        playlistSongs: _toServerPlaylistPositions(playlist),
      );
      final updated = await _playlistRestService.updatePlaylist(
        playlist.serverId,
        request,
      );
      if (!updated) {
        throw StateError('The playlist could not be updated in the cloud');
      }
    } else if (!playlist.indestructible) {
      throw StateError('The playlist does not exist in the cloud');
    }

    return _playlistRepository.savePlaylist(playlist);
  }

  Future<Song?> getMostRecentPlayedSong() async {
    var mostRecentSong = await _songService.getRecentlyPlayedSongs(1);
    if (mostRecentSong.isNotEmpty) {
      return mostRecentSong.first;
    }
    return null;
  }

  Future<Playlist> getPlaylistByName(
    String name, {
    bool indestructible = false,
  }) async {
    try {
      final serverPlaylist = await _playlistRestService
          .getPlaylistDetailsByName(name);
      return cacheServerPlaylistDetails(serverPlaylist!);
    } catch (e) {
      _logger.warning(
        "Failed to fetch playlist from server, using local version if available: $e",
      );
    }
    var queue = _playlistRepository.getOrCreatePlaylist(name);
    queue.indestructible = indestructible;
    return _playlistRepository.savePlaylist(queue);
  }

  Future<({List<Playlist> content, int totalPages, int page})>
  getIndestructiblePlaylists(int page, int size) async {
    int? serverTotalPages;
    try {
      final serverPlaylists = await _playlistRestService.getPlaylistsPage(
        filterIndestructible: true,
      );
      serverTotalPages = serverPlaylists.totalPages;
      for (final serverPlaylist in serverPlaylists.content) {
        cacheServerPlaylist(serverPlaylist);
      }
    } catch (e) {
      _logger.fine('Failed to fetch indestructible playlists from server: $e');
    }
    final localContent = _playlistRepository.getIndestructiblePlaylists(
      page * size,
      size,
    );

    for (final playlist in localContent) {
      _logger.fine('Playlist $playlist}');
    }

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_playlistRepository.getIndestructiblePlaylistCount() +
                        size -
                        1) ~/
                    size)
                .clamp(1, double.maxFinite.toInt());

    return (content: localContent, totalPages: totalPages, page: page);
  }

  Future<({List<Playlist> content, int totalPages, int page})>
  getNormalPlaylists(int page, int size) async {
    int? serverTotalPages;
    try {
      final serverPlaylists = await _playlistRestService.getPlaylistsPage(
        filterIndestructible: false,
        includeQueue: true,
      );
      serverTotalPages = serverPlaylists.totalPages;
      for (final serverPlaylist in serverPlaylists.content) {
        cacheServerPlaylist(serverPlaylist);
      }
    } catch (e) {
      _logger.fine('Failed to fetch normal playlists from server: $e');
    }
    final localContent = _playlistRepository.getNormalPlaylists(
      page * size,
      size,
    );

    for (final playlist in localContent) {
      _logger.fine('Playlist $playlist}');
    }

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_playlistRepository.getPlaylistCount('', false) + size - 1) ~/
                    size)
                .clamp(1, double.maxFinite.toInt());

    return (content: localContent, totalPages: totalPages, page: page);
  }

  Future<({List<Playlist> content, int totalPages, int page})> getPlaylistsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size, {
    bool streamOnly = false,
  }) async {
    int? serverTotalPages;
    try {
      final serverPage = await _playlistRestService.getPlaylistsPage(
        query: query,
        page: page,
        size: size,
      );
      serverTotalPages = serverPage.totalPages;

      for (final serverPlaylist in serverPage.content) {
        cacheServerPlaylist(serverPlaylist);
      }
    } catch (e) {
      _logger.fine('server fetch failed, using local: $e');
    }

    final all =
        _playlistRepository
            .getPlaylistsPaged(query, sortField, ascending, false, 0, 1 << 30)
            .where(
              (playlist) =>
                  (!containLocalOnly || playlist.isAvailableOffline) &&
                  (!streamOnly || playlist.isAvailableToStream),
            )
            .toList();
    final offset = page * size;
    final localContent =
        offset >= all.length
            ? <Playlist>[]
            : all.sublist(offset, (offset + size).clamp(0, all.length));

    for (final playlist in localContent) {
      _logger.fine('Playlist $playlist}');
    }

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((all.length + size - 1) ~/ size).clamp(
              1,
              double.maxFinite.toInt(),
            );

    return (content: localContent, totalPages: totalPages, page: page);
  }

  Future<Playlist> getPlaylistDetails(Playlist playlist) async {
    try {
      if (playlist.serverId <= 0) {
        throw Exception('Playlist does not have a valid server ID');
      }
      final serverPlaylist = await _playlistRestService.getPlaylistDetails(
        playlist.serverId,
      );
      cacheServerPlaylistDetails(serverPlaylist!);
    } catch (e) {
      _logger.fine('Failed to fetch playlist details from server: $e');
    }

    var cached = _playlistRepository.getPlaylistByName(playlist.getName());
    if (cached == null) {
      _logger.fine(
        'Playlist not found in local cache after server fetch: ${playlist.getName()}',
      );
      return playlist;
    }

    return cached;
  }

  Future<PageResult<Song>> getPlaylistSongsPageByHash(
    String playlistHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async {
    final playlists = _playlistRepository.getAllPlaylists();
    final playlist = playlists
        .where((p) => p.getHash() == playlistHash)
        .cast<Playlist?>()
        .firstWhere((p) => p != null, orElse: () => null);

    if (playlist == null) {
      return PageResult(content: const [], totalPages: 1, page: page);
    }

    return getPlaylistSongsPage(
      playlist,
      localOnly: localOnly,
      page: page,
      size: size,
    );
  }

  Future<Playlist> addToPlaylist(Playlist playlist, List<Song> songs) async {
    final previousHashes = List<String>.from(playlist.songFileHashes);
    final previousDuration = playlist.duration;
    try {
      for (var song in songs) {
        playlist.addSong(song);
      }
      _logger.fine('Updating playlist "$playlist');
      return await updatePlaylist(playlist);
    } catch (_) {
      _restoreMembership(playlist, previousHashes, previousDuration);
      rethrow;
    }
  }

  Future<void> deleteFromPlaylist(Song song, Playlist playlist) async {
    final previousHashes = List<String>.from(playlist.songFileHashes);
    final previousDuration = playlist.duration;
    try {
      playlist.removeSong(song);
      _logger.fine(
        'Updating playlist "$playlist after removing song ${song.getName()}',
      );
      await updatePlaylist(playlist);
    } catch (_) {
      _restoreMembership(playlist, previousHashes, previousDuration);
      rethrow;
    }
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    if (playlist.indestructible) {
      _logger.fine(
        "Cannot delete indestructible playlist: ${playlist.getName()}",
      );
      return;
    }
    if (playlist.serverId > 0) {
      final deleted = await _playlistRestService.deletePlaylist(
        playlist.serverId,
      );
      if (!deleted) {
        throw StateError('The playlist could not be deleted from the cloud');
      }
    } else {
      throw StateError('The playlist does not exist in the cloud');
    }
    _playlistRepository.deletePlaylist(playlist);
  }

  Playlist cacheServerPlaylist(PlaylistDto serverPlaylist) {
    if (serverPlaylist.id <= 0) {
      throw Exception('Server playlist must have a valid ID');
    }

    _logger.fine(
      'Caching server playlist: ${serverPlaylist.name} with ID ${serverPlaylist.id}',
    );

    var cachedPlaylist = _playlistRepository.getOrCreatePlaylist(
      serverPlaylist.name,
    );
    cachedPlaylist.serverId = serverPlaylist.id;
    cachedPlaylist.indestructible = serverPlaylist.indestructible;

    _mergeServerMembership(cachedPlaylist, serverPlaylist.songFileHashes);

    return _playlistRepository.savePlaylist(cachedPlaylist);
  }

  Playlist cacheServerPlaylistDetails(PlaylistExpandedDto serverPlaylist) {
    if (serverPlaylist.id <= 0) {
      throw Exception('Server playlist must have a valid ID');
    }

    var cachedPlaylist = _playlistRepository.getOrCreatePlaylist(
      serverPlaylist.name,
    );
    cachedPlaylist.serverId = serverPlaylist.id;
    cachedPlaylist.indestructible = serverPlaylist.indestructible;
    _mergeServerMembership(cachedPlaylist, serverPlaylist.songFileHashes);

    return _playlistRepository.savePlaylist(cachedPlaylist);
  }

  Future<PageResult<Song>> getPlaylistSongsPage(
    Playlist playlist, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async {
    int? serverTotalPages;
    List<Song>? serverSongs;
    try {
      if (localOnly) {
        throw Exception('Skipping server fetch due to localOnly=true');
      }
      if (playlist.serverId <= 0) {
        throw Exception('Playlist does not have a valid server ID');
      }
      final serverPage = await _playlistRestService.getPlaylistSongsPage(
        playlistId: playlist.serverId,
        page: page,
        size: size,
      );
      serverTotalPages = serverPage.totalPages;
      serverSongs = _songService.cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine(
        'PlaylistService: server fetch failed for playlist songs: $e',
      );
    }

    final localPlaylist =
        _playlistRepository.getPlaylistByName(playlist.getName()) ?? playlist;
    final hasDeviceOnlySongs = _deviceOnlyHashes(localPlaylist).isNotEmpty;
    if (serverSongs != null && !hasDeviceOnlySongs) {
      return PageResult(
        content: serverSongs,
        totalPages: serverTotalPages ?? 1,
        page: page,
      );
    }

    final ordered = _resolvePlaylistSongs(
      localPlaylist.songFileHashes,
      localOnly,
    );

    final total = ordered.length;
    final start = page * size;
    final content =
        start >= total
            ? const <Song>[]
            : ordered.sublist(start, (start + size).clamp(0, total));
    final totalPages = ((total + size - 1) ~/ size).clamp(
      1,
      double.maxFinite.toInt(),
    );

    return PageResult(content: content, totalPages: totalPages, page: page);
  }

  List<Song> _resolvePlaylistSongs(List<String> songFileHashes, bool localOnly) {
    final wanted = songFileHashes.toSet();
    final byHash = <String, Song>{};
    for (final song in _songService.getAllLocalCandidates()) {
      if (!song.fullyLoaded) continue;
      if (localOnly && !song.isAvailableOffline) continue;
      final identities = <String>{
        song.getHash(),
        if (song.fileHash.isNotEmpty) song.fileHash,
        ...song.potentialRemoteHashes.where((hash) => hash.isNotEmpty),
      };
      for (final hash in identities.where(wanted.contains)) {
        final existing = byHash[hash];
        if (existing == null ||
            (!existing.isAvailableOffline && song.isAvailableOffline)) {
          byHash[hash] = song;
        }
      }
    }
    return [
      for (final hash in songFileHashes)
        if (byHash[hash] != null) byHash[hash]!,
    ];
  }

  List<PlaylistSongPositionDto> _toServerSongPositions(List<Song> songs) {
    final hashes = <String>[];
    for (final song in songs) {
      final hash = _remoteHashFor(song);
      if (hash != null && !hashes.contains(hash)) hashes.add(hash);
    }
    return [
      for (final (position, hash) in hashes.indexed)
        PlaylistSongPositionDto(songFileHash: hash, position: position),
    ];
  }

  List<PlaylistSongPositionDto> _toServerPlaylistPositions(
    Playlist playlist,
  ) {
    final byIdentity = <String, Song>{};
    for (final song in _songService.getAllLocalCandidates()) {
      byIdentity[song.getHash()] = song;
      if (song.fileHash.isNotEmpty) byIdentity[song.fileHash] = song;
      for (final hash in song.potentialRemoteHashes) {
        if (hash.isNotEmpty) byIdentity[hash] = song;
      }
    }

    final hashes = <String>[];
    for (final storedHash in playlist.songFileHashes) {
      final song = byIdentity[storedHash];
      final remoteHash =
          song == null
              ? (storedHash.startsWith('local:') ? null : storedHash)
              : _remoteHashFor(song);
      if (remoteHash != null && !hashes.contains(remoteHash)) {
        hashes.add(remoteHash);
      }
    }
    return [
      for (final (position, hash) in hashes.indexed)
        PlaylistSongPositionDto(songFileHash: hash, position: position),
    ];
  }

  String? _remoteHashFor(Song song) {
    if (song.localSourceKey == null && song.fileHash.isNotEmpty) {
      return song.fileHash;
    }
    return song.potentialRemoteHashes
        .where((hash) => hash.isNotEmpty)
        .firstOrNull;
  }

  Set<String> _deviceOnlyHashes(Playlist playlist) {
    final candidates = {
      for (final song in _songService.getAllLocalCandidates())
        song.getHash(): song,
    };
    return {
      for (final hash in playlist.songFileHashes)
        if (candidates[hash] != null &&
            _remoteHashFor(candidates[hash]!) == null)
          hash,
    };
  }

  void _mergeServerMembership(Playlist playlist, List<String> serverHashes) {
    final candidates = {
      for (final song in _songService.getAllLocalCandidates())
        song.getHash(): song,
    };
    final deviceOnly = _deviceOnlyHashes(playlist);
    final serverRemaining = serverHashes.toSet();
    final merged = <Song>[];

    for (final existingHash in playlist.songFileHashes) {
      final local = candidates[existingHash];
      if (deviceOnly.contains(existingHash) && local != null) {
        merged.add(local);
        continue;
      }
      final remoteHash = local == null ? existingHash : _remoteHashFor(local);
      if (remoteHash != null && serverRemaining.remove(remoteHash)) {
        merged.add(_songRepository.getOrCreateSong(remoteHash));
      }
    }
    for (final hash in serverHashes.where(serverRemaining.remove)) {
      merged.add(_songRepository.getOrCreateSong(hash));
    }

    playlist.clearSongs();
    for (final song in merged) {
      playlist.addSong(song);
    }
  }

  void _restoreMembership(
    Playlist playlist,
    List<String> hashes,
    int duration,
  ) {
    final byIdentity = <String, Song>{};
    for (final song in _songService.getAllLocalCandidates()) {
      byIdentity[song.getHash()] = song;
      if (song.fileHash.isNotEmpty) byIdentity[song.fileHash] = song;
      for (final hash in song.potentialRemoteHashes) {
        if (hash.isNotEmpty) byIdentity[hash] = song;
      }
    }
    playlist.clearSongs();
    for (final hash in hashes) {
      final song = byIdentity[hash];
      if (song != null) {
        playlist.addSong(song);
      } else if (!hash.startsWith('local:')) {
        playlist.addSong(_songRepository.getOrCreateSong(hash));
      }
    }
    playlist.duration = duration;
  }
}
