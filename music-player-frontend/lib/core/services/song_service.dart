import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/played_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/played_song_repo.dart';
import 'package:music_player_frontend/core/repository/song_repo.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

class SongService {
  final SongRepository _songRepository;
  final PlayedSongRepository _playedSongRepository;
  final FileService _fileService;
  final SettingsService _settingsService;

  SongService(
    this._songRepository,
    this._playedSongRepository,
    this._fileService,
    this._settingsService,
  );

  Stream watchSongs() => _songRepository.watchSongs();

  Stream watchPlayedSongs() => _playedSongRepository.watchPlayedSongs();

  Future<Song> addSong(String songPath) async {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }
    Song newSong = Song();
    var metadata = await _fileService.retrieveSong(songPath);
    newSong.fromJson(metadata);
    return _songRepository.saveSong(newSong);
  }

  bool isInitialScanComplete() {
    try {
      final settingsBox = ObjectBox.store.box<AppSettings>();
      final settings = settingsBox.get(1);
      return settings?.initialScanComplete ?? false;
    } catch (e) {
      debugPrint("Error checking initial scan status: $e");
      return false;
    }
  }

  void markInitialScanComplete() {
    try {
      final settingsBox = ObjectBox.store.box<AppSettings>();
      var settings = settingsBox.get(1);
      if (settings == null) {
        settings =
            AppSettings()
              ..id = 1
              ..initialScanComplete = true;
      } else {
        settings.initialScanComplete = true;
      }
      settingsBox.put(settings);
      debugPrint("Initial scan marked as complete");
    } catch (e) {
      debugPrint("Error marking initial scan complete: $e");
    }
  }

  Song addSongEntity(Song song) {
    return _songRepository.saveSong(song);
  }

  Song? getSong(String songPath) {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
      return _songRepository.getSongByPath(songPath);
    } catch (e) {
      // debugPrint("Error fetching song with path '$songPath': $e");
      return null;
    }
  }

  Song? getSongContaining(String query) {
    if (query.isEmpty) {
      throw ArgumentError("Query cannot be empty");
    }

    try {
      return _songRepository.getSongContaining(query);
    } catch (e) {
      debugPrint("Error fetching song containing '$query': $e");
      return null;
    }
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    return _songRepository.getSongs(query, sortField, flag);
  }

  List<Song> getAllSongs() {
    return _songRepository.getAllSongs();
  }

  void updateSong(Song song) {
    _songRepository.updateSong(song);
  }

  void updateSongPlayed(Song song) {
    PlayedSong playedSong = PlayedSong();
    playedSong.song.target = song;
    playedSong.playedAt = DateTime.now();
    _playedSongRepository.savePlayedSong(playedSong);
  }

  void deleteSong(Song song) {
    _songRepository.deleteSong(song);
  }

  List<Song> getSongsFromPaths(List<String> paths) {
    if (paths.isEmpty) {
      return [];
    }
    List<Song> songs = [];
    for (String path in paths) {
      final song = getSong(path);
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
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
