import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/song_repo.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';

class SongService {
  final SongRepository _songRepository;
  final SongRestService _songRestService;

  SongService(this._songRepository, this._songRestService);

  Map<String, dynamic> get sortFields => _songRepository.sortFields;

  Song addSongEntity(Song song) {
    return _songRepository.saveSong(song);
  }

  int getSongCount() {
    return _songRepository.getSongCount();
  }

  List<Song> addSongsEntitiesBatch(List<Song> songs) {
    debugPrint("Adding batch of ${songs.length} songs to the database");
    return _songRepository.saveSongs(songs);
  }

  void addSongsBatch(List<Song> songs) {
    for (var song in songs) {
      _songRepository.saveSong(song);
    }
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

  Future<List<Song>> getServerSongs() async {
    return await _songRestService.getAllSongs();
  }

  void updateSong(Song song) {
    _songRepository.updateSong(song);
  }

  void updateSongsBatch(List<Song> songs) {
    _songRepository.updateSongs(songs);
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

  void linkToServerId(int localId, int serverId) {
    final song = _songRepository.getSong(localId);
    song.serverId = serverId;
    _songRepository.updateSong(song);
  }

  void recordPlay(int songId) {
    final song = _songRepository.getSong(songId);
    song.playCount++;
    song.lastPlayed = DateTime.now();
    song.requiresSync = true;
    _songRepository.updateSong(song);
  }
}
