import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';

import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/file_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/utils/constants.dart';

class SongService {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

  final PlaylistService _playlistService;

  SongService(this._playlistService);

  Stream watchSongs() => _songBox.query().watch(triggerImmediately: true);


  Future<Song> addSong(String songPath) async {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }
    Song newSong = Song();
    var metadata = await FileService.retrieveSong(songPath);
    newSong.fromJson(metadata);
    newSong.id = _songBox.put(newSong);
    return newSong;
  }

  Song? getSong(String songPath) {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
      return _songBox.query(Song_.path.equals(songPath)).build().findUnique();
    } catch (e) {
      debugPrint("Error fetching song with path '$songPath': $e");
      return null;
    }
  }

  Song? getSongContaining(String query) {
    if (query.isEmpty) {
      throw ArgumentError("Query cannot be empty");
    }

    try {
      return _songBox.query(Song_.path.contains(query, caseSensitive: false)).build().findFirst();
    } catch (e) {
      debugPrint("Error fetching song containing '$query': $e");
      return null;
    }
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    Query<Song> builderQuery;
    if (flag == false) {
      builderQuery = _songBox
          .query(Song_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Song_.name : Song_.duration,
      ).build();
    }
    else {
      builderQuery = _songBox
          .query(Song_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Song_.name : Song_.duration,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  List<Song> getAllSongs() {
    return _songBox.getAll();
  }

  void updateSong(Song song) {
    _songBox.put(song);
    _playlistService.updateFavorites(_songBox.query(Song_.liked.equals(true)).build().find());


    var query = _songBox.query().order(Song_.lastPlayed, flags: Order.descending).build();
    query.limit = 50;
    _playlistService.updateRecentlyPlayed(query.find());

    query = _songBox.query(Song_.playCount.greaterThan(0)).order(Song_.playCount, flags: Order.descending).build();
    query.limit = 50;
    _playlistService.updateMostPlayed(query.find());
  }

  void deleteSong(Song song) {
    _songBox.remove(song.id);
  }


  List<Song> getSongsFromPaths(List<String> paths)  {
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

  // Future<void> retrieveAllSongs() async {
  //   var appSettings = settingsService.getAppSettings() ?? AppSettings();
  //   List<String> songPlaces = appSettings.songPlaces;
  //   final audioFiles = await FileService.getAudioFiles(songPlaces);
  //
  //   for (final file in audioFiles) {
  //     final song = songRepo.getSong(file.path);
  //     if (song == null) {
  //       debugPrint("Adding new song: ${file.path}");
  //       final song = Song();
  //       song.path = file.path;
  //       song.name = file.path.split('/').last;
  //       song.existsExternally = true;
  //       songRepo.addSong(song);
  //
  //       // try {
  //       //   debugPrint("Retrieving metadata for ${file.path}");
  //       //   final metadata = await retrieveMetadata(file.path);
  //       //   debugPrint("Retrieved metadata for ${file.path}.");
  //       //   song.fromJson(metadata);
  //       //   //debugPrint("Retrieved metadata for ${file.path}: ${song.id}");
  //       //   song.fullyLoaded = true;
  //       //   songRepo.updateSong(song);
  //       //   albumService.addSongToAlbum(song, song.album);
  //       //   artistService.addSongToArtist(song, song.trackArtist);
  //       // } catch (e) {
  //       //   debugPrint("Error retrieving metadata for ${file.path}: $e");
  //       // }
  //
  //       Isolate.run(() => FileService.retrieveSong(file.path)).then((metadata) {
  //         song.fromJson(metadata);
  //         //debugPrint("Retrieved metadata for ${file.path}: ${song.id}");
  //         song.fullyLoaded = true;
  //         songRepo.updateSong(song);
  //         albumService.addSongToAlbum(song, song.album);
  //         artistService.addSongToArtist(song, song.trackArtist);
  //       })
  //           .catchError((error) {
  //         debugPrint("Error retrieving metadata for ${file.path}: $error");
  //       });
  //     }
  //     else if (song.fullyLoaded == false) {
  //       // try {
  //       //   debugPrint("Retrieving metadata for ${file.path}");
  //       //   final metadata = await retrieveMetadata(file.path);
  //       //   debugPrint("Retrieved metadata for ${file.path}.");
  //       //   song.fromJson(metadata);
  //       //   //debugPrint("Retrieved metadata for ${file.path}: ${song.id}");
  //       //   song.fullyLoaded = true;
  //       //   songRepo.updateSong(song);
  //       //   albumService.addSongToAlbum(song, song.album);
  //       //   artistService.addSongToArtist(song, song.trackArtist);
  //       // } catch (e) {
  //       //   debugPrint("Error retrieving metadata for ${file.path}: $e");
  //       // }
  //       song.existsExternally = true;
  //       songRepo.updateSong(song);
  //       Isolate.run(() => FileService.retrieveSong(file.path)).then((metadata) {
  //         song.fromJson(metadata);
  //         //debugPrint("Retrieved metadata for ${file.path}: ${song.id}");
  //         song.fullyLoaded = true;
  //         songRepo.updateSong(song);
  //         albumService.addSongToAlbum(song, song.album);
  //         artistService.addSongToArtist(song, song.trackArtist);
  //       }).catchError((error) {
  //         debugPrint("Error retrieving metadata for ${file.path}: $error");
  //       });
  //     }
  //   }
  //
  //   List<Song> nonExistingSongs = songRepo.getNonExistingSongs();
  //   for (final song in nonExistingSongs) {
  //     //debugPrint("Checking if song ${song.name} exists externally.");
  //     if (FileService.fileExists(song.path) == false) {
  //       debugPrint("Song ${song.name} does not exist anymore, deleting it.");
  //       songRepo.deleteSong(song);
  //     } else {
  //       song.existsExternally = true;
  //       songRepo.updateSong(song);
  //     }
  //   }
  // }
}