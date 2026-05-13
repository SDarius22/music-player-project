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
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
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

    try {
      final coverBase64 = coverArt != null ? base64Encode(coverArt) : null;
      final request = CreatePlaylistDto(
        name: name,
        playlistSongs:
            songs
                .asMap()
                .entries
                .map(
                  (e) => PlaylistSongPositionDto(
                    songFileHash: e.value.getHash(),
                    position: e.key,
                  ),
                )
                .toList(),
        coverImageBase64: coverBase64,
      );
      final result = await _playlistRestService.createPlaylist(request);
      if (result != null) {
        newPlaylist.serverId = result.id;
      }
    } catch (e) {
      _logger.fine('failed to create playlist on server: $e');
    }

    return _playlistRepository.savePlaylist(newPlaylist);
  }

  Future<Playlist> updatePlaylist(Playlist playlist) async {
    if (playlist.serverId > 0) {
      try {
        final request = UpdatePlaylistDto(
          name: playlist.getName(),
          playlistSongs:
              playlist
                  .getSongs()
                  .asMap()
                  .entries
                  .map(
                    (e) => PlaylistSongPositionDto(
                      songFileHash: e.value.getHash(),
                      position: e.key,
                    ),
                  )
                  .toList(),
        );
        await _playlistRestService.updatePlaylist(playlist.serverId, request);
      } catch (e) {
        _logger.fine('failed to update playlist on server: $e');
      }
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
    int size,
  ) async {
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

    final localContent = _playlistRepository.getPlaylistsPaged(
      query,
      sortField,
      ascending,
      containLocalOnly,
      page * size,
      size,
    );

    for (final playlist in localContent) {
      _logger.fine('Playlist $playlist}');
    }

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_playlistRepository.getPlaylistCount(query, containLocalOnly) +
                        size -
                        1) ~/
                    size)
                .clamp(1, double.maxFinite.toInt());

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
    for (var song in songs) {
      playlist.addSong(song);
    }
    _logger.fine('Updating playlist "$playlist');
    return await updatePlaylist(playlist);
  }

  Future<void> deleteFromPlaylist(Song song, Playlist playlist) async {
    playlist.removeSong(song);
    _logger.fine(
      'Updating playlist "$playlist after removing song ${song.getName()}',
    );
    await updatePlaylist(playlist);
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    if (playlist.indestructible) {
      _logger.fine(
        "Cannot delete indestructible playlist: ${playlist.getName()}",
      );
      return;
    }
    if (playlist.serverId > 0) {
      try {
        await _playlistRestService.deletePlaylist(playlist.serverId);
      } catch (e) {
        _logger.fine('failed to delete playlist on server: $e');
      }
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

    for (final hash in serverPlaylist.songFileHashes) {
      final song = _songService.getOrCreateSong(hash);
      if (!cachedPlaylist.getSongs().contains(song)) {
        cachedPlaylist.addSong(song);
      }
    }

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
    cachedPlaylist.clearSongs();

    for (var songHash in serverPlaylist.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSong(songHash);

      cachedPlaylist.addSong(cachedSong);
    }

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

    if (serverSongs != null) {
      return PageResult(
        content: serverSongs,
        totalPages: serverTotalPages ?? 1,
        page: page,
      );
    }

    final localPlaylist =
        _playlistRepository.getPlaylistByName(playlist.getName()) ?? playlist;
    final localSongs = _songRepository.getPlaylistSongsPaged(
      localPlaylist.songFileHashes,
      localOnly,
      page * size,
      size,
    );

    final totalPages = ((_songRepository.getPlaylistSongCount(
                  localPlaylist.songFileHashes,
                  localOnly,
                ) +
                size -
                1) ~/
            size)
        .clamp(1, double.maxFinite.toInt());

    return PageResult(content: localSongs, totalPages: totalPages, page: page);
  }
}
