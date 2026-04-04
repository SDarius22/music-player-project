import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/dtos/playlist_page_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/playlist_rest_service.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepository;
  final SongRepository _songRepository;
  final PlaylistRestService _playlistRestService;

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
      final songFileHashes = songs
          .map((s) => s.fileHash)
          .where((h) => h.isNotEmpty)
          .toList();
      final coverBase64 = coverArt != null ? base64Encode(coverArt) : null;
      final result = await _playlistRestService.createPlaylist(
        name, songFileHashes, coverBase64,
      );
      if (result != null) {
        newPlaylist.serverId = (result['id'] as num).toInt();
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
        final songFileHashes = playlist.songs
            .map((s) => s.fileHash)
            .where((h) => h.isNotEmpty)
            .toList();
        final coverBase64 = playlist.imageBytes != null
            ? base64Encode(playlist.imageBytes!)
            : null;
        await _playlistRestService.updatePlaylist(
          playlist.serverId, playlist.name, songFileHashes, coverBase64,
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

  Future<PlaylistPageDto> getPlaylistsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    try {
      final serverPage = await _playlistRestService.getPlaylistsPage(
        page: page,
        size: size,
      );

      for (final serverPlaylist in serverPage.content) {
        cacheServerPlaylist(serverPlaylist);
      }

      if (serverPage.totalElements > 0) {
        final content = _playlistRepository.getPlaylistsPaged(
          query, sortField, ascending, page * size, size,
        );
        return PlaylistPageDto(
          content: content,
          page: page,
          size: size,
          totalPages: serverPage.totalPages,
          totalElements: serverPage.totalElements,
        );
      }
    } catch (e) {
      debugPrint('PlaylistService: server fetch failed, using local: $e');
    }
    return _localPage(query, sortField, ascending, page, size);
  }

  Playlist cacheServerPlaylist(Playlist serverPlaylist) {
    if (serverPlaylist.serverId > 0) {
      final byServerId = _playlistRepository.getPlaylistByServerId(
        serverPlaylist.serverId,
      );
      if (byServerId != null) {
        byServerId.name = serverPlaylist.name;
        _resolveAndSetSongs(byServerId, serverPlaylist.serverSongFileHashes);
        _playlistRepository.savePlaylist(byServerId);
        return byServerId;
      }
    }

    final byName = _playlistRepository.getPlaylistByName(serverPlaylist.name);
    if (byName != null && !byName.indestructible) {
      if (byName.serverId <= 0 && serverPlaylist.serverId > 0) {
        byName.serverId = serverPlaylist.serverId;
      }
      _resolveAndSetSongs(byName, serverPlaylist.serverSongFileHashes);
      _playlistRepository.savePlaylist(byName);
      return byName;
    }

    _resolveAndSetSongs(serverPlaylist, serverPlaylist.serverSongFileHashes);
    return _playlistRepository.savePlaylist(serverPlaylist);
  }

  void _resolveAndSetSongs(Playlist playlist, List<String> songFileHashes) {
    if (songFileHashes.isEmpty) return;
    final resolved = songFileHashes
        .map((hash) => _songRepository.getSongByFileHash(hash))
        .whereType<Song>()
        .toList();
    if (resolved.isNotEmpty) {
      playlist.songs.clear();
      playlist.songFileHashes.clear();
      for (final song in resolved) {
        playlist.songs.add(song);
        playlist.songFileHashes.add(song.fileHash);
      }
    }
  }

  PlaylistPageDto _localPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) {
    final all = _playlistRepository.getPlaylists(query, sortField, ascending);
    final totalElements = all.length;
    final totalPages = (totalElements / size).ceil();
    final offset = page * size;
    if (offset >= totalElements) {
      return PlaylistPageDto(
        content: const [],
        page: page,
        size: size,
        totalPages: totalPages,
        totalElements: totalElements,
      );
    }
    final content = all.sublist(
      offset,
      (offset + size).clamp(0, totalElements),
    );
    return PlaylistPageDto(
      content: content,
      page: page,
      size: size,
      totalPages: totalPages,
      totalElements: totalElements,
    );
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
