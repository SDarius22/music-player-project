import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';

class PlaylistService {
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
    String whereToAdd,
    Uint8List? coverArt,
  ) async {
    Playlist newPlaylist = Playlist();
    newPlaylist.name = name;
    newPlaylist.nextAdded = whereToAdd;
    newPlaylist.imageBytes = coverArt;
    addToPlaylist(newPlaylist, songs);
    _playlistRepository.savePlaylist(newPlaylist);

    try {
      final songFileHashes =
          songs.map((s) => s.fileHash).where((h) => h.isNotEmpty).toList();
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
      debugPrint('PlaylistService: failed to create playlist on server: $e');
    }

    return newPlaylist;
  }

  Future<Playlist> updatePlaylist(Playlist playlist) async {
    if (playlist.indestructible) {
      final list = playlist.songsList;
      if (list.isNotEmpty) {
        playlist.imageBytes = list.first.coverArt;
      }
    }
    _playlistRepository.savePlaylist(playlist);

    if (playlist.serverId > 0) {
      try {
        final songFileHashes =
            playlist.songs
                .map((s) => s.fileHash)
                .where((h) => h.isNotEmpty)
                .toList();
        final coverBase64 =
            playlist.imageBytes != null
                ? base64Encode(playlist.imageBytes!)
                : null;
        await _playlistRestService.updatePlaylist(
          playlist.serverId,
          playlist.name,
          songFileHashes,
          coverBase64,
        );
      } catch (e) {
        debugPrint('PlaylistService: failed to update playlist on server: $e');
      }
    }

    return playlist;
  }

  Playlist? getPlaylist(int playlistId) {
    return _playlistRepository.getPlaylist(playlistId);
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
    if (_playlistRepository.getPlaylistByName("Queue") != null) {
      return;
    }
    Playlist queue = Playlist();
    queue.id = 1;
    queue.name = "Queue";
    queue.indestructible = true;
    queue.nextAdded = "last";
    _playlistRepository.savePlaylist(queue);
  }

  Playlist getQueuePlaylist() {
    var queue = _playlistRepository.getPlaylistByName("Queue");
    if (queue == null) {
      debugPrint("Queue playlist not found, initializing...");
      initializeQueue();
      return _playlistRepository.getPlaylistByName("Queue")!;
    } else {
      return queue;
    }
  }

  void initializeFavorites() {
    if (_playlistRepository.getPlaylistByName("Favorites") != null) {
      return;
    }
    Playlist favorites = Playlist();
    favorites.id = 2;
    favorites.name = "Favorites";
    favorites.indestructible = true;
    favorites.nextAdded = "last";
    _playlistRepository.savePlaylist(favorites);
  }

  Playlist getFavoritesPlaylist() {
    var favorites = _playlistRepository.getPlaylistByName("Favorites");
    if (favorites == null) {
      debugPrint("Favorites playlist not found, initializing...");
      initializeFavorites();
      return _playlistRepository.getPlaylistByName("Favorites")!;
    } else {
      return favorites;
    }
  }

  void initializeMostPlayed() {
    if (_playlistRepository.getPlaylistByName("Most Played") != null) {
      return;
    }
    Playlist mostPlayed = Playlist();
    mostPlayed.id = 3;
    mostPlayed.name = "Most Played";
    mostPlayed.indestructible = true;
    mostPlayed.nextAdded = "last";
    _playlistRepository.savePlaylist(mostPlayed);
  }

  void initializeRecentlyPlayed() {
    if (_playlistRepository.getPlaylistByName("Recently Played") != null) {
      return;
    }
    Playlist recentlyPlayed = Playlist();
    recentlyPlayed.id = 4;
    recentlyPlayed.name = "Recently Played";
    recentlyPlayed.indestructible = true;
    recentlyPlayed.nextAdded = "last";
    _playlistRepository.savePlaylist(recentlyPlayed);
  }

  void updateMostPlayedPlaylist() {
    Playlist? mostPlayed = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.name == "Most Played");
    if (mostPlayed == null) {
      debugPrint("Most Played playlist not found");
      return;
    }
    List<Song> topSongs = _songRepository.getMostPlayedSongs(50);
    debugPrint("Updating Most Played with ${topSongs.length} songs");
    mostPlayed.songs.clear();
    mostPlayed.songFileHashes.clear();
    addToPlaylist(mostPlayed, topSongs);
  }

  void updateRecentlyPlayedPlaylist() {
    Playlist? recentlyPlayed = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.name == "Recently Played");
    if (recentlyPlayed == null) {
      debugPrint("Recently Played playlist not found");
      return;
    }
    List<Song> recentSongs = _songRepository.getRecentlyPlayedSongs(50);
    recentlyPlayed.songs.clear();
    recentlyPlayed.songFileHashes.clear();
    addToPlaylist(recentlyPlayed, recentSongs);
  }

  void updateFavoritesPlaylist() {
    Playlist? favorites = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.name == "Favorites");
    if (favorites == null) {
      debugPrint("Favorites playlist not found");
      return;
    }
    List<Song> favoriteSongs = _songRepository.getFavoriteSongs();
    favorites.songs.clear();
    favorites.songFileHashes.clear();
    addToPlaylist(favorites, favoriteSongs);
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistRepository.getIndestructiblePlaylists();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistRepository.getNormalPlaylists();
  }

  List<Playlist> getPlaylists(String query, String sortField, bool flag) {
    return _playlistRepository.getPlaylists(query, sortField, flag);
  }

  Future<
    ({List<Playlist> content, int totalPages, int totalElements, int page})
  >
  getPlaylistsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    int? serverTotalPages;
    int? serverTotalElements;
    try {
      final serverPage = await _playlistRestService.getPlaylistsPage(
        page: page,
        size: size,
      );
      if (serverPage.totalElements > 0) {
        serverTotalPages = serverPage.totalPages;
        serverTotalElements = serverPage.totalElements;
        for (final dto in serverPage.content) {
          cacheServerPlaylist(_playlistDtoToEntity(dto));
        }
      }
    } catch (e) {
      debugPrint('PlaylistService: server fetch failed, using local: $e');
    }

    final allLocal = _playlistRepository.getPlaylists(
      query,
      sortField,
      ascending,
    );
    final localTotal = allLocal.length;
    final effectiveTotalElements = serverTotalElements ?? localTotal;
    final effectiveTotalPages =
        serverTotalPages ?? ((localTotal + size - 1) ~/ size).clamp(1, 999999);

    final localContent = _playlistRepository.getPlaylistsPaged(
      query,
      sortField,
      ascending,
      page * size,
      size,
    );

    return (
      content: localContent,
      totalPages: effectiveTotalPages,
      totalElements: effectiveTotalElements,
      page: page,
    );
  }

  Playlist cacheServerPlaylist(Playlist serverPlaylist) {
    if (serverPlaylist.serverId <= 0) {
      throw Exception('Server playlist must have a valid ID');
    }

    // Look up by serverId first.
    var cached = _playlistRepository.getPlaylistByServerId(
      serverPlaylist.serverId,
    );

    if (cached == null) {
      // Fall back to name lookup, but never hijack an indestructible playlist.
      final byName = _playlistRepository.getPlaylistByName(serverPlaylist.name);
      if (byName != null && !byName.indestructible) {
        cached = byName;
        if (cached.serverId <= 0) {
          cached.serverId = serverPlaylist.serverId;
        }
      } else {
        // Not found (or found indestructible) — save the entity as-is.
        return _playlistRepository.savePlaylist(serverPlaylist);
      }
    }

    cached.name = serverPlaylist.name;

    for (final hash in serverPlaylist.serverSongFileHashes) {
      final song = _songRepository.getSongByFileHash(hash);
      if (song != null && !cached.songFileHashes.contains(hash)) {
        cached.songs.add(song);
        cached.songFileHashes.add(hash);
      }
    }

    return _playlistRepository.savePlaylist(cached);
  }

  Playlist _playlistDtoToEntity(PlaylistDto dto) {
    final p = Playlist();
    p.serverId = dto.id;
    p.name = dto.name;
    p.serverSongFileHashes = dto.songFileHashes;
    return p;
  }

  List<Playlist> getAllPlaylists() {
    return _playlistRepository.getAllPlaylists();
  }

  void addToPlaylist(Playlist playlist, List<Song> songs) {
    if (playlist.nextAdded == 'last') {
      for (var song in songs) {
        playlist.songFileHashes.add(song.fileHash);
        playlist.songs.add(song);
      }
    } else {
      for (var song in songs.reversed) {
        playlist.songFileHashes.insert(0, song.fileHash);
        playlist.songs.add(song);
      }
    }
    updatePlaylist(playlist);
  }

  void deleteFromPlaylist(Song song, Playlist playlist) {
    try {
      playlist.songFileHashes.remove(song.fileHash);
      playlist.songs.remove(song);
      _playlistRepository.savePlaylist(playlist);
    } catch (e) {
      debugPrint("Error removing song from playlist: $e");
    }
  }

  void deleteAllSongsFromPlaylist(Playlist playlist) {
    playlist.songFileHashes.clear();
    playlist.songs.clear();
    _playlistRepository.savePlaylist(playlist);
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    if (playlist.indestructible) {
      debugPrint("Cannot delete indestructible playlist: ${playlist.name}");
      return;
    }
    if (playlist.serverId > 0) {
      try {
        await _playlistRestService.deletePlaylist(playlist.serverId);
      } catch (e) {
        debugPrint('PlaylistService: failed to delete playlist on server: $e');
      }
    }
    _playlistRepository.deletePlaylist(playlist);
  }
}
