import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/utils/constants.dart';

class PlaylistService {
  Box<Playlist> get _playlistBox => ObjectBox.store.box<Playlist>();

  PlaylistService() {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
  }

  Stream watchPlaylists() => _playlistBox.query().watch(triggerImmediately: true);

  Playlist addPlaylist(String name, List<Song> songs, String whereToAdd, Uint8List? coverArt) {
    Playlist newPlaylist = Playlist();
    newPlaylist.name = name;
    newPlaylist.nextAdded = whereToAdd;
    newPlaylist.coverArt = coverArt;
    addToPlaylist(newPlaylist, songs);
    newPlaylist.id = _playlistBox.put(newPlaylist);
    return newPlaylist;
  }

  Playlist? getPlaylist(int playlistId) {
    return _playlistBox.get(playlistId);
  }

  void initializeIndestructible() {
    initializeFavorites();
    initializeMostPlayed();
    initializeRecentlyPlayed();
    initializeAllSongsPlaylist();
  }

  void initializeFavorites() {
    if (_playlistBox.query(Playlist_.name.equals("Favorites")).build().findUnique() != null) {
      return;
    }
    Playlist favorites = Playlist();
    favorites.id = favoritesId;
    favorites.name = "Favorites";
    favorites.indestructible = true;
    favorites.visible = true;
    favorites.nextAdded = "last";
    _playlistBox.put(favorites);
  }

  void initializeMostPlayed() {
    if (_playlistBox.query(Playlist_.name.equals("Most Played")).build().findUnique() != null) {
      return;
    }
    Playlist mostPlayed = Playlist();
    mostPlayed.id = mostPlayedId;
    mostPlayed.name = "Most Played";
    mostPlayed.indestructible = true;
    mostPlayed.visible = true;
    mostPlayed.nextAdded = "last";
    _playlistBox.put(mostPlayed);
  }

  void initializeRecentlyPlayed() {
    if (_playlistBox.query(Playlist_.name.equals("Recently Played")).build().findUnique() != null) {
      return;
    }
    Playlist recentlyPlayed = Playlist();
    recentlyPlayed.id = recentlyPlayedId;
    recentlyPlayed.name = "Recently Played";
    recentlyPlayed.indestructible = true;
    recentlyPlayed.visible = true;
    recentlyPlayed.nextAdded = "last";
    _playlistBox.put(recentlyPlayed);
  }

  void initializeAllSongsPlaylist() {
    if (_playlistBox.query(Playlist_.name.equals("{all.songs.playlist}")).build().findUnique() != null) {
      return;
    }
    Playlist allSongs = Playlist();
    allSongs.id = allSongsId;
    allSongs.name = "{all.songs.playlist}";
    allSongs.indestructible = true;
    allSongs.visible = true;
    allSongs.nextAdded = "last";
    _playlistBox.put(allSongs);
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistBox.query(Playlist_.indestructible.equals(true)).order(Playlist_.name).build().find();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistBox.query(Playlist_.indestructible.equals(false)).order(Playlist_.name).build().find();
  }

  List<Playlist> getPlaylists(String query, String sortField, bool flag) {
    Query<Playlist> builderQuery;
    if (flag == false) {
      builderQuery = _playlistBox
          .query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
      ).build();
    } else {
      builderQuery = _playlistBox
          .query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  List<Playlist> getAllPlaylists() {
    return _playlistBox.getAll();
  }

  void addToPlaylist(Playlist playlist, List<Song> songs) {
    if (playlist.nextAdded == 'last') {
      for (var song in songs) {
        debugPrint("Adding song: ${song.name}, play count: ${song.playCount} to playlist: ${playlist.name}");
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
    _playlistBox.put(playlist);
    // exportPlaylist(playlist);
  }

  void deleteFromPlaylist(Playlist playlist, Song song) {
    try {
      playlist.pathsInOrder.remove(song.path);
      playlist.songs.remove(song);
      _playlistBox.put(playlist);
    }
    catch (e) {
      debugPrint("Error removing song from playlist: $e");
    }
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    _playlistBox.remove(playlist.id);
  }

  void updateFavorites(List<Song> songs) {
    Playlist? favorites = getPlaylist(favoritesId);
    if (favorites == null) {
      favorites = Playlist();
      favorites.name = "Favorites";
    }
    favorites.pathsInOrder = [];
    favorites.songs.clear();
    addToPlaylist(favorites, songs);
    _playlistBox.put(favorites);
  }

  void updateMostPlayed(List<Song> songs) {
    Playlist? mostPlayed =  getPlaylist(mostPlayedId);
    if (mostPlayed == null) {
      mostPlayed = Playlist();
      mostPlayed.name = "Most Played";
    }

    mostPlayed.pathsInOrder = [];
    mostPlayed.songs.clear();
    addToPlaylist(mostPlayed, songs);
    _playlistBox.put(mostPlayed);
  }

  void updateRecentlyPlayed(List<Song> songs) {
    Playlist? recentlyPlayed =  getPlaylist(recentlyPlayedId);
    if (recentlyPlayed == null) {
      recentlyPlayed = Playlist();
      recentlyPlayed.name = "Recently Played";
    }
    recentlyPlayed.pathsInOrder = [];
    recentlyPlayed.songs.clear();
    addToPlaylist(recentlyPlayed, songs);
    _playlistBox.put(recentlyPlayed);
  }

}