import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepository;
  final SongRepository _songRepository;

  PlaylistService(this._playlistRepository, this._songRepository) {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
  }

  Stream watchPlaylists() => _playlistRepository.watchPlaylists();

  Map<String, dynamic> get sortFields => _playlistRepository.sortFields;

  Playlist addPlaylist(
    String name,
    List<Song> songs,
    String whereToAdd,
    Uint8List coverArt,
  ) {
    Playlist newPlaylist = Playlist();
    newPlaylist.name = name;
    newPlaylist.nextAdded = whereToAdd;
    newPlaylist.imageBytes = coverArt;
    addToPlaylist(newPlaylist, songs);
    return _playlistRepository.savePlaylist(newPlaylist);
  }

  Playlist updatePlaylist(Playlist playlist) {
    if (playlist.indestructible) {
      playlist.imageBytes = playlist.songsList.first.coverArt;
    }
    return _playlistRepository.savePlaylist(playlist);
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
    mostPlayed.songsIds.clear();
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
    recentlyPlayed.songsIds.clear();
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
    favorites.songsIds.clear();
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

  List<Playlist> getAllPlaylists() {
    return _playlistRepository.getAllPlaylists();
  }

  void addToPlaylist(Playlist playlist, List<Song> songs) {
    if (playlist.nextAdded == 'last') {
      for (var song in songs) {
        playlist.songsIds.add(song.id);
        playlist.songs.add(song);
      }
    } else {
      for (var song in songs.reversed) {
        playlist.songsIds.insert(0, song.id);
        playlist.songs.add(song);
      }
    }
    updatePlaylist(playlist);
  }

  void deleteFromPlaylist(Song song, Playlist playlist) {
    try {
      playlist.songsIds.remove(song.id);
      playlist.songs.remove(song);
      _playlistRepository.savePlaylist(playlist);
    } catch (e) {
      debugPrint("Error removing song from playlist: $e");
    }
  }

  void deleteAllSongsFromPlaylist(Playlist playlist) {
    playlist.songsIds.clear();
    playlist.songs.clear();
    _playlistRepository.savePlaylist(playlist);
  }

  void deletePlaylist(Playlist playlist) {
    if (playlist.indestructible) {
      debugPrint("Cannot delete indestructible playlist: ${playlist.name}");
      return;
    }
    _playlistRepository.deletePlaylist(playlist);
  }
}
