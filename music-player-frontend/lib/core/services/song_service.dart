import 'dart:async';

import 'package:flutter/foundation.dart';
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

  Stream watchSongs() => songRepo.watchAllSongs();


  Future<void> addSong(String songPath) async {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    // Check if the song already exists
    final existingSong =  songRepo.getSong(songPath);
    if (existingSong != null) {
      throw Exception("Song with path '$songPath' already exists");
    }

    Song newSong = Song();
    var metadata = await FileService.retrieveSong(songPath);
    newSong.fromJson(metadata);

    try {
       songRepo.addSong(newSong);
    } catch (e) {
      throw Exception("Error adding song: $e");
    }
  }

  Song? getSong(String songPath) {
    if (songPath.isEmpty) {
      throw ArgumentError("Song path cannot be empty");
    }

    try {
      return songRepo.getSong(songPath);
    } catch (e) {
      debugPrint("Error fetching song: $e");
      return null;
    }
  }

  Song? getSongContaining(String query) {
    if (query.isEmpty) {
      throw ArgumentError("Query cannot be empty");
    }

    try {
      return songRepo.getSongContaining(query);
    } catch (e) {
      debugPrint("Error fetching song containing '$query': $e");
      return null;
    }
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    try {
      return songRepo.getSongs(query, sortField, flag);
    } catch (e) {
      debugPrint("Error fetching songs: $e");
      return [];
    }
  }

  List<Song> getAllSongs() {
    try {
      return songRepo.getAllSongs();
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

  List<Song> getSongsFromPaths(List<String> paths) {
    if (paths.isEmpty) {
      return [];
    }

    try {
      return songRepo.getSongsFromPaths(paths);
    } catch (e) {
      debugPrint("Error fetching songs from paths: $e");
      return [];
    }
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