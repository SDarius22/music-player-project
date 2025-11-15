import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/playlist_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/played_song_repo.dart';
import 'package:music_player_frontend/core/repository/playlist_repo.dart';
import 'package:music_player_frontend/core/repository/playlist_song_repo.dart';

class PlaylistService {
  final PlaylistRepository _playlistRepository;
  final PlaylistSongRepository _playlistSongRepository;
  final PlayedSongRepository _playedSongRepository;

  PlaylistService(
    this._playlistRepository,
    this._playlistSongRepository,
    this._playedSongRepository,
  ) {
    if (getIndestructiblePlaylists().isEmpty) {
      initializeIndestructible();
    }
    _playedSongsStream.listen((_) {
      debugPrint("Played songs stream updated");
      updateIndestructiblePlaylists();
    });
  }

  Stream watchPlaylists() => _playlistRepository.watchPlaylists();

  get _playedSongsStream => _playedSongRepository.songAdded;

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

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistRepository.getIndestructiblePlaylists();
  }

  void updateIndestructiblePlaylists() {
    updateQueue();
    updateMostPlayedPlaylist();
    updateRecentlyPlayedPlaylist();
  }

  void updateQueue() {
    Playlist? queue = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.name == "Queue");
    if (queue == null) {
      debugPrint("Queue playlist not found");
      return;
    }
    // placeholder for future functionality
  }

  void updateMostPlayedPlaylist() {
    Playlist? mostPlayed = _playlistRepository
        .getIndestructiblePlaylists()
        .firstWhereOrNull((pl) => pl.name == "Most Played");
    if (mostPlayed == null) {
      debugPrint("Most Played playlist not found");
      return;
    }
    List<Song> topSongs = getMostPlayedSongs(50);
    debugPrint("Updating Most Played with ${topSongs.length} songs");
    mostPlayed.playlistSongs.clear();
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
    List<Song> recentSongs = getRecentlyPlayedSongs(50);
    recentlyPlayed.playlistSongs.clear();
    addToPlaylist(recentlyPlayed, recentSongs);
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
        _addLastToPlaylist(playlist, song);
      }
    } else {
      for (var song in songs.reversed) {
        _addFirstToPlaylist(playlist, song);
      }
    }
    _playlistRepository.savePlaylist(playlist);
  }

  void addToIndexedPositionInPlaylist(
    Playlist playlist,
    Song song,
    double position,
  ) {
    var playlistSongs = playlist.playlistSongs;
    if (playlistSongs.any((ps) => ps.song.targetId == song.id)) {
      debugPrint("Song '${song.id}' already in playlist");
      return;
    }
    PlaylistSong ps = PlaylistSong();
    ps.playlist.target = playlist;
    ps.song.target = song;
    ps.position = position;
    playlist.playlistSongs.add(_playlistSongRepository.savePlaylistSong(ps));
    _playlistRepository.savePlaylist(playlist);
  }

  void _addLastToPlaylist(Playlist playlist, Song song) {
    var playlistSongs = playlist.playlistSongs;
    double maxOrder =
        playlistSongs.isNotEmpty ? playlistSongs.last.position : 0.0;
    if (playlistSongs.any((ps) => ps.song.targetId == song.id)) {
      debugPrint("Song '${song.id}' already in playlist");
      return;
    }
    maxOrder += 1;
    PlaylistSong ps = PlaylistSong();
    ps.playlist.target = playlist;
    ps.song.target = song;
    ps.position = maxOrder;
    playlist.playlistSongs.add(_playlistSongRepository.savePlaylistSong(ps));
    _playlistRepository.savePlaylist(playlist);
  }

  void _addFirstToPlaylist(Playlist playlist, Song song) {
    var playlistSongs = playlist.playlistSongs;
    double minOrder =
        playlistSongs.isNotEmpty ? playlistSongs.first.position : 0.0;
    if (playlistSongs.any((ps) => ps.song.targetId == song.id)) {
      debugPrint("Song '${song.id}' already in playlist");
      return;
    }
    minOrder -= 1;
    PlaylistSong ps = PlaylistSong();
    ps.playlist.target = playlist;
    ps.song.target = song;
    ps.position = minOrder;
    playlist.playlistSongs.add(_playlistSongRepository.savePlaylistSong(ps));
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

  List<Song> getMostPlayedSongs(int limit) {
    return _playedSongRepository
        .getMostPlayedSongs(limit)
        .map((ps) => ps.song.target)
        .whereType<Song>()
        .toList();
  }

  List<Song> getRecentlyPlayedSongs(int limit) {
    return _playedSongRepository
        .getRecentPlayedSongs(limit)
        .map((ps) => ps.song.target)
        .whereType<Song>()
        .toList();
  }
}
