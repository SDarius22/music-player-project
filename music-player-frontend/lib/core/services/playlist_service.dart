import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/playlist_repo.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepo;
  final SongService songService;

  PlaylistService(this._playlistRepo, this.songService) {
    if (_playlistRepo.getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
    songService.watchSongs().listen((_) {
      debugPrint("Songs updated, updating indestructible playlists");
      updateIndestructible();
    });
  }

  Stream watchPlaylists() => _playlistRepo.watchAllPlaylists();

  void addPlaylist(String name, List<String> songs, String whereToAdd, Uint8List? coverArt) {
    if (name.isEmpty) {
      throw ArgumentError("Playlist name cannot be empty");
    }
    if (songs.isEmpty) {
      throw ArgumentError("Playlist must contain at least one song");
    }
    // Check if the playlist already exists
    final existingPlaylist =  _playlistRepo.getPlaylist(name);
    if (existingPlaylist != null) {
      throw Exception("Playlist with name '$name' already exists");
    }
    Playlist newPlaylist = Playlist();
    newPlaylist.name = name;
    newPlaylist.nextAdded = whereToAdd;
    newPlaylist.coverArt = coverArt;
    List<Song> songObjects = [];
    for (var songPath in songs) {
      Song? song = songService.getSong(songPath);
      if (song != null) {
        songObjects.add(song);
      } else {
        debugPrint("Song not found: $songPath");
      }
    }
    addToPlaylist(newPlaylist, songObjects);
    try {
       _playlistRepo.addPlaylist(newPlaylist);
    } catch (e) {
      debugPrint("Error adding playlist: $e");
    }
  }

  Playlist? getPlaylist(String name) {
    if (name.isEmpty) {
      throw ArgumentError("Playlist name cannot be empty");
    }
    try {
      return _playlistRepo.getPlaylist(name);
    } catch (e) {
      debugPrint("Error fetching playlist: $e");
      return null;
    }
  }

  void initializeIndestructible() {
    Playlist mostPlayed = Playlist();
    mostPlayed.name = "Most Played";
    mostPlayed.pathsInOrder = [];
    mostPlayed.artistCount = [];
    mostPlayed.duration = 0;
    mostPlayed.indestructible = true;
    Playlist recentlyPlayed = Playlist();
    recentlyPlayed.name = "Recently Played";
    recentlyPlayed.pathsInOrder = [];
    recentlyPlayed.artistCount = [];
    recentlyPlayed.duration = 0;
    recentlyPlayed.indestructible = true;
    Playlist favorites = Playlist();
    favorites.name = "Favorites";
    favorites.pathsInOrder = [];
    favorites.artistCount = [];
    favorites.duration = 0;
    favorites.indestructible = true;
    _playlistRepo.addPlaylist(mostPlayed);
    _playlistRepo.addPlaylist(recentlyPlayed);
    _playlistRepo.addPlaylist(favorites);
  }

  List<Playlist> getIndestructiblePlaylists() {
    try {
      return _playlistRepo.getIndestructiblePlaylists();
    } catch (e) {
      debugPrint("Error fetching indestructible playlists: $e");
      return [];
    }
  }

  List<Playlist> getNormalPlaylists() {
    try {
      return _playlistRepo.getNormalPlaylists();
    } catch (e) {
      debugPrint("Error fetching normal playlists: $e");
      return [];
    }
  }

  List<Playlist> getPlaylists(String query, String sortField, bool flag) {
    try {
      return _playlistRepo.getPlaylists(query, sortField, flag);
    } catch (e) {
      debugPrint("Error fetching playlists: $e");
      return [];
    }
  }

  List<Playlist> getAllPlaylists() {
    try {
      return _playlistRepo.getAllPlaylists();
    } catch (e) {
      debugPrint("Error fetching all playlists: $e");
      return [];
    }
  }

  void addToPlaylist(Playlist playlist, List<Song> songs) {
    if (playlist.nextAdded == 'last') {
      for (var song in songs) {
        debugPrint("Adding song: ${song.name}, play count: ${song.playCount} to playlist: ${playlist.name}");
        if (playlist.pathsInOrder.contains(song.path)) {
          continue;
        }
        playlist.pathsInOrder.add(song.path);
        playlist.duration += song.duration;
        playlist.songs.add(song);
        bool found = false;
        for (var artistCountStr in playlist.artistCount){
          if (artistCountStr.contains(song.artist.target?.name ?? "Unknown Artist")){
            int count = int.parse(artistCountStr.split(" - ")[1]);
            count += 1;
            playlist.artistCount.remove(artistCountStr);
            playlist.artistCount.add("${song.artist.target?.name ?? "Unknown Artist"} - $count");
            found = true;
            break;
          }
        }
        if (!found){
          playlist.artistCount.add("${song.artist.target?.name ?? "Unknown Artist"} - 1");
        }
      }
      _playlistRepo.updatePlaylist(playlist);
    } else {
      for (int i = songs.length - 1; i >= 0; i--) {
        if (playlist.pathsInOrder.contains(songs[i].path)) {
          continue;
        }
        playlist.pathsInOrder.insert(0, songs[i].path);
        playlist.duration += songs[i].duration;
        playlist.songs.insert(0, songs[i]);
        bool found = false;
        for (var artistCountStr in playlist.artistCount){
          if (artistCountStr.contains(songs[i].artist.target?.name ?? "Unknown Artist")){
            int count = int.parse(artistCountStr.split(" - ")[1]);
            count += 1;
            playlist.artistCount.remove(artistCountStr);
            playlist.artistCount.add("${songs[i].artist.target?.name ?? "Unknown Artist"} - $count");
            found = true;
            break;
          }
        }
        if (!found){
          playlist.artistCount.add("${songs[i].artist.target?.name ?? "Unknown Artist"} - 1");
        }
      }
      _playlistRepo.updatePlaylist(playlist);
    }
    // exportPlaylist(playlist);
  }

  void deleteFromPlaylist(Playlist playlist, String song) {
    if (!playlist.pathsInOrder.contains(song)) {
      throw Exception("Song not found in playlist");
    }
    try {
      Song songObj = playlist.songs.firstWhere((s) => s.path == song);
      playlist.pathsInOrder.remove(song);
      playlist.duration -= songObj.duration;
      for (var artistCountStr in playlist.artistCount){
        if (artistCountStr.contains(songObj.artist.target?.name ?? "Unknown Artist")){
          int count = int.parse(artistCountStr.split(" - ")[1]);
          count -= 1;
          playlist.artistCount.remove(artistCountStr);
          if (count > 0) {
            playlist.artistCount.add("${songObj.artist.target?.name ?? "Unknown Artist"} - $count");
          }
          break;
        }
      }
      _playlistRepo.updatePlaylist(playlist);
    }
    catch (e) {
      debugPrint("Error removing song from playlist: $e");
    }
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    if (playlist.id == 0) {
      throw ArgumentError("Playlist ID cannot be zero");
    }
    try {
       _playlistRepo.deletePlaylist(playlist);
      // Optionally, delete the associated file if it exists
      // var file = File("${FileService.mainSongPlace}/${playlist.name}.m3u");
      // if (file.existsSync()) {
      //   file.deleteSync();
      // }
    } catch (e) {
      debugPrint("Error deleting playlist: $e");
    }
  }

  void updateIndestructible() {
    updateFavorites();
    updateMostPlayed();
    updateRecentlyPlayed();
  }

  void updateFavorites() {
    Playlist? favorites =  _playlistRepo.getPlaylist("Favorites");
    if (favorites == null) {
      favorites = Playlist();
      favorites.name = "Favorites";
    }
    // var query = songBox.query(Song_.isFavorite.equals(true)).build();
    var songs = songService.getFavoriteSongs();
    favorites.artistCount = [];
    favorites.pathsInOrder = [];
    favorites.songs.clear();
    favorites.duration = 0;
    addToPlaylist(favorites, songs);
    _playlistRepo.updatePlaylist(favorites);
  }

  void updateMostPlayed() {
    Playlist? mostPlayed =  _playlistRepo.getPlaylist("Most Played");
    if (mostPlayed == null) {
      mostPlayed = Playlist();
      mostPlayed.name = "Most Played";
    }
    // var query = songBox.query(Song_.playCount.greaterThan(0)).order(Song_.playCount, flags: Order.descending).build();
    // query.limit = 100;
    var songs = songService.getSongsWithPlayCount();
    mostPlayed.artistCount = [];
    mostPlayed.pathsInOrder = [];
    mostPlayed.songs.clear();
    mostPlayed.duration = 0;
    addToPlaylist(mostPlayed, songs);
    _playlistRepo.updatePlaylist(mostPlayed);
  }

  void updateRecentlyPlayed() {
    Playlist? recentlyPlayed =  _playlistRepo.getPlaylist("Recently Played");
    if (recentlyPlayed == null) {
      recentlyPlayed = Playlist();
      recentlyPlayed.name = "Recently Played";
    }
    // var query = songBox.query(Song_.lastPlayed.notNull()).order(Song_.lastPlayed, flags: Order.descending).build();
    // query.limit = 100;
    var songs = songService.getSongsWithLastPlayed();
    recentlyPlayed.artistCount = [];
    recentlyPlayed.pathsInOrder = [];
    recentlyPlayed.songs.clear();
    recentlyPlayed.duration = 0;
    addToPlaylist(recentlyPlayed, songs);
    _playlistRepo.updatePlaylist(recentlyPlayed);
  }
}