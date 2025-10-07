import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/playlist_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/playlist_repo.dart';
import 'package:music_player_frontend/core/repository/playlist_song_repo.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepository;
  final PlaylistSongRepository _playlistSongRepository;

  PlaylistService(this._playlistRepository, this._playlistSongRepository) {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
  }

  Stream watchPlaylists() => _playlistRepository.watchPlaylists();

  get sortFields => _playlistRepository.sortFields;

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
    var playlistSongs = _playlistSongRepository.getPlaylistSongs(playlist.id);

    if (playlist.nextAdded == 'last') {
      int maxOrder = playlistSongs.last.order;
      for (var song in songs) {
        if (playlistSongs.any((ps) => ps.song.targetId == song.id)) {
          continue;
        }
        maxOrder += 1;
        PlaylistSong ps = PlaylistSong();
        ps.playlist.target = playlist;
        ps.song.target = song;
        ps.order = maxOrder;
        _playlistSongRepository.savePlaylistSong(ps);
      }
      // for (var song in songs) {
      //   if (playlist.pathsInOrder.contains(song.path)) {
      //     continue;
      //   }
      //   playlist.pathsInOrder.add(song.path);
      //   playlist.songs.add(song);
      // }
    } else {
      int minOrder = playlistSongs.isNotEmpty ? playlistSongs.first.order : 0;
      for (var song in songs.reversed) {
        if (playlistSongs.any((ps) => ps.song.targetId == song.id)) {
          continue;
        }
        minOrder -= 1;
        PlaylistSong ps = PlaylistSong();
        ps.playlist.target = playlist;
        ps.song.target = song;
        ps.order = minOrder;
        _playlistSongRepository.savePlaylistSong(ps);
      }
      // for (int i = songs.length - 1; i >= 0; i--) {
      //   if (playlist.pathsInOrder.contains(songs[i].path)) {
      //     continue;
      //   }
      //   playlist.pathsInOrder.insert(0, songs[i].path);
      //   playlist.songs.insert(0, songs[i]);
      // }
    }
    _playlistRepository.savePlaylist(playlist);
  }

  void deleteFromPlaylist(Song song, Playlist playlist) {
    try {
      _playlistSongRepository.deletePlaylistSong(song, playlist.id);
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
}
