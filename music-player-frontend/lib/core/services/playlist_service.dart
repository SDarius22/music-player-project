import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/playlist_repo.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepository;

  PlaylistService(this._playlistRepository) {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
  }

  Stream watchPlaylists() => _playlistRepository.watchPlaylists();

  Playlist addPlaylist(
    String name,
    List<Song> songs,
    String whereToAdd,
    Uint8List? coverArt,
  ) {
    Playlist newPlaylist = Playlist();
    newPlaylist.name = name;
    newPlaylist.nextAdded = whereToAdd;
    newPlaylist.coverArt = coverArt;
    addToPlaylist(newPlaylist, songs);
    return _playlistRepository.savePlaylist(newPlaylist);
  }

  Playlist? getPlaylist(int playlistId) {
    return _playlistRepository.getPlaylist(playlistId);
  }

  void initializeIndestructible() {
    initializeFavorites();
    initializeMostPlayed();
    initializeRecentlyPlayed();
  }

  void initializeFavorites() {
    if (_playlistRepository.getPlaylistByName("Favorites") != null) {
      return;
    }
    Playlist favorites = Playlist();
    favorites.name = "Favorites";
    favorites.indestructible = true;
    favorites.nextAdded = "last";
    _playlistRepository.savePlaylist(favorites);
  }

  void initializeMostPlayed() {
    if (_playlistRepository.getPlaylistByName("Most Played") != null) {
      return;
    }
    Playlist mostPlayed = Playlist();
    mostPlayed.name = "Most Played";
    mostPlayed.indestructible = true;
    mostPlayed.visible = true;
    mostPlayed.nextAdded = "last";
    _playlistRepository.savePlaylist(mostPlayed);
  }

  void initializeRecentlyPlayed() {
    if (_playlistRepository.getPlaylistByName("Recently Played") != null) {
      return;
    }
    Playlist recentlyPlayed = Playlist();
    recentlyPlayed.name = "Recently Played";
    recentlyPlayed.indestructible = true;
    recentlyPlayed.visible = true;
    recentlyPlayed.nextAdded = "last";
    _playlistRepository.savePlaylist(recentlyPlayed);
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
        debugPrint(
          "Adding song: ${song.name}, play count: ${song.playCount} to playlist: ${playlist.name}",
        );
        if (playlist.pathsInOrder.contains(song.path)) {
          continue;
        }
        playlist.pathsInOrder.add(song.path);
        playlist.songs.add(song);
      }
    } else {
      for (int i = songs.length - 1; i >= 0; i--) {
        if (playlist.pathsInOrder.contains(songs[i].path)) {
          continue;
        }
        playlist.pathsInOrder.insert(0, songs[i].path);
        playlist.songs.insert(0, songs[i]);
      }
    }
    _playlistRepository.savePlaylist(playlist);
  }

  void deleteFromPlaylist(Playlist playlist, Song song) {
    try {
      playlist.pathsInOrder.remove(song.path);
      playlist.songs.remove(song);
      _playlistRepository.savePlaylist(playlist);
    } catch (e) {
      debugPrint("Error removing song from playlist: $e");
    }
  }

  void deletePlaylist(Playlist playlist) {
    if (playlist.indestructible) {
      debugPrint("Cannot delete indestructible playlist: ${playlist.name}");
      return;
    }
    _playlistRepository.deletePlaylist(playlist);
  }

  void updateFavorites(List<Song> songs) {
    Playlist? favorites = _playlistRepository.getPlaylistByName("Favorites");
    if (favorites == null) {
      favorites = Playlist();
      favorites.name = "Favorites";
    }
    favorites.pathsInOrder = [];
    favorites.songs.clear();
    addToPlaylist(favorites, songs);
    _playlistRepository.savePlaylist(favorites);
  }

  void updateMostPlayed(List<Song> songs) {
    Playlist? mostPlayed = _playlistRepository.getPlaylistByName("Most Played");
    if (mostPlayed == null) {
      mostPlayed = Playlist();
      mostPlayed.name = "Most Played";
    }

    mostPlayed.pathsInOrder = [];
    mostPlayed.songs.clear();
    addToPlaylist(mostPlayed, songs);
    _playlistRepository.savePlaylist(mostPlayed);
  }

  void updateRecentlyPlayed(List<Song> songs) {
    Playlist? recentlyPlayed = _playlistRepository.getPlaylistByName(
      "Recently Played",
    );
    if (recentlyPlayed == null) {
      recentlyPlayed = Playlist();
      recentlyPlayed.name = "Recently Played";
    }
    recentlyPlayed.pathsInOrder = [];
    recentlyPlayed.songs.clear();
    addToPlaylist(recentlyPlayed, songs);
    _playlistRepository.savePlaylist(recentlyPlayed);
  }
}
