import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';

class PlaylistService {
  static final _logger = Logger('PlaylistService');

  final PlaylistRepository _playlistRepository;
  final SongRepository _songRepository;
  final PlaylistRestClient _playlistRestService;

  PlaylistService(
    this._playlistRepository,
    this._songRepository,
    this._playlistRestService,
  ) {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
  }

  Stream watchPlaylists() => _playlistRepository.watchPlaylists();

  Map<String, dynamic> get sortFields => _playlistRepository.sortFields;

  Future<Playlist> addPlaylist(
    String name,
    List<Song> songs,
    Uint8List? coverArt,
  ) async {
    Playlist newPlaylist = Playlist(name, songs: songs);
    newPlaylist.imageBytes = coverArt;
    _playlistRepository.savePlaylist(newPlaylist);

    try {
      final songFileHashes =
          songs.map((s) => s.getHash()).where((h) => h.isNotEmpty).toList();
      final coverBase64 = coverArt != null ? base64Encode(coverArt) : null;
      final result = await _playlistRestService.createPlaylist(
        name,
        songFileHashes,
        coverBase64,
      );
      if (result != null) {
        newPlaylist.serverId = result.id;
        _playlistRepository.savePlaylist(newPlaylist);
      }
    } catch (e) {
      _logger.fine('failed to create playlist on server: $e');
    }

    return newPlaylist;
  }

  Future<Playlist> updatePlaylist(Playlist playlist) async {
    if (playlist.indestructible) {
      final list = playlist.getSongs();
      _logger.fine('Updating cover art for indestructible playlist $playlist');
      if (list.isNotEmpty) {
        playlist.imageBytes = list.first.getCoverArt();
      }
    }

    if (playlist.serverId > 0) {
      try {
        final songFileHashes =
            playlist
                .getSongs()
                .map((s) => s.getHash())
                .where((h) => h.isNotEmpty)
                .toList();
        final coverBase64 =
            playlist.imageBytes != null
                ? base64Encode(playlist.imageBytes!)
                : null;
        await _playlistRestService.updatePlaylist(
          playlist.serverId,
          playlist.getName(),
          songFileHashes,
          coverBase64,
        );
      } catch (e) {
        _logger.fine('failed to update playlist on server: $e');
      }
    }

    return _playlistRepository.savePlaylist(playlist);
  }

  Song? getMostRecentPlayedSong() {
    return _songRepository.getMostRecentPlayedSong();
  }

  void initializeIndestructible() {
    initializeQueue();
    initializeFavorites();
    initializeMostPlayed();
    initializeRecentlyPlayed();
  }

  void initializeQueue() {
    if (_playlistRepository.getPlaylistByServerIdAndName(-1, "Queue") != null) {
      return;
    }
    Playlist queue = Playlist("Queue");
    queue.indestructible = true;
    _playlistRepository.savePlaylist(queue);
  }

  Playlist getQueuePlaylist() {
    var queue = _playlistRepository.getPlaylistByServerIdAndName(-1, "Queue");
    if (queue == null) {
      _logger.fine("Queue playlist not found, initializing...");
      initializeQueue();
      return _playlistRepository.getPlaylistByServerIdAndName(-1, "Queue")!;
    } else {
      return queue;
    }
  }

  void initializeFavorites() {
    if (_playlistRepository.getPlaylistByServerIdAndName(-1, "Favorites") !=
        null) {
      return;
    }
    Playlist favorites = Playlist("Favorites");
    favorites.indestructible = true;
    _playlistRepository.savePlaylist(favorites);
  }

  Playlist getFavoritesPlaylist() {
    var favorites = _playlistRepository.getPlaylistByServerIdAndName(
      -1,
      "Favorites",
    );
    if (favorites == null) {
      _logger.fine("Favorites playlist not found, initializing...");
      initializeFavorites();
      return _playlistRepository.getPlaylistByServerIdAndName(-1, "Favorites")!;
    } else {
      return favorites;
    }
  }

  void initializeMostPlayed() {
    if (_playlistRepository.getPlaylistByServerIdAndName(-1, "Most Played") !=
        null) {
      return;
    }
    Playlist mostPlayed = Playlist("Most Played");
    mostPlayed.indestructible = true;
    _playlistRepository.savePlaylist(mostPlayed);
  }

  void initializeRecentlyPlayed() {
    if (_playlistRepository.getPlaylistByServerIdAndName(
          -1,
          "Recently Played",
        ) !=
        null) {
      return;
    }
    Playlist recentlyPlayed = Playlist("Recently Played");
    recentlyPlayed.indestructible = true;
    _playlistRepository.savePlaylist(recentlyPlayed);
  }

  void updateMostPlayedPlaylist() {
    Playlist? mostPlayed = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.getName() == "Most Played");
    if (mostPlayed == null) {
      _logger.fine("Most Played playlist not found");
      return;
    }
    List<Song> topSongs = _songRepository.getMostPlayedSongs(50);
    _logger.fine("Updating Most Played with ${topSongs.length} songs");
    mostPlayed.clearSongs();
    addToPlaylist(mostPlayed, topSongs);
  }

  void updateRecentlyPlayedPlaylist() {
    Playlist? recentlyPlayed = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.getName() == "Recently Played");
    if (recentlyPlayed == null) {
      _logger.fine("Recently Played playlist not found");
      return;
    }
    List<Song> recentSongs = _songRepository.getRecentlyPlayedSongs(50);
    recentlyPlayed.clearSongs();
    addToPlaylist(recentlyPlayed, recentSongs);
  }

  void updateFavoritesPlaylist() {
    Playlist? favorites = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.getName() == "Favorites");
    if (favorites == null) {
      _logger.fine("Favorites playlist not found");
      return;
    }
    List<Song> favoriteSongs = _songRepository.getFavoriteSongs();
    favorites.clearSongs();
    addToPlaylist(favorites, favoriteSongs);
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistRepository.getIndestructiblePlaylists();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistRepository.getNormalPlaylists();
  }

  Future<({List<Playlist> content, int totalPages, int page})> getPlaylistsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    int? serverTotalPages;
    try {
      final serverPage = await _playlistRestService.getPlaylistsPage(
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
      page * size,
      size,
    );

    for (final playlist in localContent) {
      _logger.fine('Playlist $playlist}');
    }

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_playlistRepository
                            .getPlaylists(query, sortField, ascending)
                            .length +
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

    var cached = _playlistRepository.getPlaylistByServerIdAndName(
      playlist.serverId,
      playlist.getName(),
    );
    if (cached == null) {
      _logger.fine(
        'Playlist not found in local cache after server fetch: ${playlist.getName()}',
      );
      return playlist;
    }

    return cached;
  }

  Playlist cacheServerPlaylist(PlaylistDto serverPlaylist) {
    if (serverPlaylist.id <= 0) {
      throw Exception('Server playlist must have a valid ID');
    }

    _logger.fine(
      'Caching server playlist: ${serverPlaylist.name} with ID ${serverPlaylist.id}',
    );

    var cachedPlaylist = _playlistRepository.getOrCreatePlaylist(
      serverPlaylist.id,
      serverPlaylist.name,
    );

    for (final hash in serverPlaylist.songFileHashes) {
      final song = _songRepository.getOrCreateSong(hash);
      if (!cachedPlaylist.getSongs().contains(song)) {
        cachedPlaylist.addSong(song);
      }
    }

    return _playlistRepository.savePlaylist(cachedPlaylist);
  }

  Playlist cacheServerPlaylistDetails(PlaylistDetailDto serverPlaylist) {
    if (serverPlaylist.id <= 0) {
      throw Exception('Server playlist must have a valid ID');
    }

    var cachedPlaylist = _playlistRepository.getOrCreatePlaylist(
      serverPlaylist.id,
      serverPlaylist.name,
    );

    cachedPlaylist.clearSongs();

    for (final song in serverPlaylist.songs) {
      final cachedSong = _songRepository.getOrCreateSong(song.fileHash);
      cachedPlaylist.addSong(cachedSong);
    }

    return _playlistRepository.savePlaylist(cachedPlaylist);
  }

  List<Playlist> getAllPlaylists() {
    return _playlistRepository.getAllPlaylists();
  }

  Future<Playlist> addToPlaylist(Playlist playlist, List<Song> songs) async {
    for (var song in songs) {
      playlist.addSong(song);
    }
    _logger.fine('Updating playlist "$playlist');
    return await updatePlaylist(playlist);
  }

  void deleteFromPlaylist(Song song, Playlist playlist) {
    try {
      playlist.removeSong(song);
      _playlistRepository.savePlaylist(playlist);
    } catch (e) {
      _logger.fine("Error removing song from playlist: $e");
    }
  }

  void deleteAllSongsFromPlaylist(Playlist playlist) {
    playlist.clearSongs();
    _playlistRepository.savePlaylist(playlist);
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
}
