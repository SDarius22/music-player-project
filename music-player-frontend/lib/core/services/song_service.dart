import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/song_repo.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/file_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

class SongService {
  final SongsRepository songRepo;
  final SettingsService settingsService;
  final AlbumService albumService;
  final ArtistService artistService;

  SongService(this.songRepo, this.settingsService, this.albumService, this.artistService);


  Future<Song?> getSong(String songPath) async {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
      return await songRepo.getSong(songPath);
    } catch (e) {
      debugPrint("Error fetching song: $e");
      return null;
    }
  }

  Future<Song?> getSongContaining(String query) async {
    if (query.isEmpty) {
      throw ArgumentError("Query cannot be empty");
    }

    try {
      return await songRepo.getSongContaining(query);
    } catch (e) {
      debugPrint("Error fetching song containing '$query': $e");
      return null;
    }
  }

  Future<List<Song>> getSongs(String query, bool flag) async {
    try {
      return await songRepo.getSongs(query, flag);
    } catch (e) {
      debugPrint("Error fetching songs: $e");
      return [];
    }
  }

  Future<List<Song>> getAllSongs() async {
    try {
      return await songRepo.getAllSongs();
    } catch (e) {
      debugPrint("Error fetching all songs: $e");
      return [];
    }
  }

  void updateSong(Song song) {
    if (song.path.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
       songRepo.updateSong(song);
    } catch (e) {
      debugPrint("Error updating song: $e");
    }
  }

  void deleteSong(Song song) {
    if (song.path.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
       songRepo.deleteSong(song);
    } catch (e) {
      debugPrint("Error deleting song: $e");
    }
  }

  List<Song> getFavoriteSongs() {
    try {
      return songRepo.getFavoriteSongs();
    } catch (e) {
      debugPrint("Error fetching favorite songs: $e");
      return [];
    }
  }

  List<Song> getSongsWithPlayCount() {
    try {
      return  songRepo.getSongsWithPlayCount();
    } catch (e) {
      debugPrint("Error fetching songs with play count: $e");
      return [];
    }
  }

  List<Song> getSongsWithLastPlayed() {
    try {
      return  songRepo.getSongsWithLastPlayed();
    } catch (e) {
      debugPrint("Error fetching songs with last played: $e");
      return [];
    }
  }
}