import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:watcher/watcher.dart';

abstract class FileService {
  get supportedAudioExtensions;

  // static const supportedAudioExtensions = [
  //   'aac', // AAC (ADTS)
  //   'ape', // Monkey's Audio
  //   'aiff', // AIFF
  //   'aif', // Sometimes used as alternate for AIFF
  //   'flac', // FLAC
  //   'mp3', // MP3
  //   'mp4', // MP4 (audio, like M4A)
  //   'm4a', // M4A is common for audio-only MP4
  //   'mpc', // Musepack
  //   'opus', // Opus
  //   'ogg', // Ogg Vorbis
  //   'oga', // Audio-specific extension for Ogg (optional)
  //   'spx', // Speex
  //   'wav', // WAV
  //   'wv', // WavPack
  // ];

  bool isSupportedAudioFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return supportedAudioExtensions.contains(extension);
  }

  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  });

  //   Map<String, dynamic>? metadataVariable = {};
  //   metadataVariable['path'] = path;
  //
  //   AudioMetadata metadataVar;
  //   try {
  //     metadataVar = readMetadata(File(path), getImage: withImage);
  //   } catch (e) {
  //     debugPrint("Error reading metadata for $path: $e");
  //     metadataVariable['title'] = path.replaceAll("\\", "/").split("/").last;
  //     return metadataVariable;
  //   }
  //   metadataVariable['title'] =
  //       metadataVar.title ?? path.replaceAll("\\", "/").split("/").last;
  //   metadataVariable['album'] = metadataVar.album ?? "Unknown Album";
  //   metadataVariable['duration'] = metadataVar.duration ?? 0;
  //   metadataVariable['trackNumber'] = metadataVar.trackNumber ?? 0;
  //   metadataVariable['trackArtist'] = metadataVar.artist ?? "Unknown Artist";
  //   metadataVariable['discNumber'] = metadataVar.discNumber ?? 0;
  //   metadataVariable['year'] = metadataVar.year ?? 0;
  //   metadataVariable['image'] =
  //       metadataVar.pictures.isNotEmpty
  //           ? metadataVar.pictures[0].bytes
  //           : logoImage;
  //   metadataVariable['lyricsPath'] = _getLyricsPath(path);
  //   return metadataVariable;
  // }

  String getLyricsPath(String songPath) {
    var lyrPath = songPath.replaceRange(
      songPath.lastIndexOf("."),
      songPath.length,
      ".lrc",
    );
    if (File(lyrPath).existsSync()) {
      return lyrPath;
    }
    return "";
  }

  Future<List<File>> getAudioFiles(List<String> songPlaces);

  //   // Use a Queue for efficient directory traversal
  //   List<File> files = [];
  //   Queue<Directory> dirs = Queue<Directory>();
  //   for (String dir in songPlaces) {
  //     dirs.add(Directory(dir));
  //   }
  //
  //   //List<MetadataType> newSongs = [];
  //
  //   while (dirs.isNotEmpty) {
  //     final dir = dirs.removeFirst();
  //     await for (FileSystemEntity entity in dir.list(followLinks: false)) {
  //       if (entity is File && _isSupportedAudioFile(entity.path)) {
  //         files.add(File(entity.path));
  //         // if (!paths.contains(entity.path)) {
  //         //   paths.add(entity.path);
  //         //   // debugPrint("Adding $path");
  //         //   // var song = await retrieveSong(entity.path);
  //         //   // debugPrint("Added song: ${song.title}");
  //         //   // songBox.put(song);
  //         //   // await makeAlbumArtist(song);
  //         // }
  //       } else if (entity is Directory) {
  //         dirs.add(Directory(entity.path));
  //       }
  //     }
  //   }
  //   return files;
  // }

  Future<Uint8List> getImage(String path);

  // if (path.isEmpty) {
  //   return Constants.logoBytes;
  // }
  // try {
  //   var metadataVar = readMetadata(File(path), getImage: true);
  //   return metadataVar.pictures.isNotEmpty
  //       ? metadataVar.pictures[0].bytes
  //       : Constants.logoBytes;
  // } catch (e) {
  //   debugPrint("Error reading image metadata for $path: $e");
  // }
  // return Constants.logoBytes;

  Stream watchForFileChanges(List<String> songPlaces) {
    List<Stream> streams = [];
    for (String path in songPlaces) {
      if (path.isNotEmpty) {
        var watcher = DirectoryWatcher(path);
        streams.add(watcher.events);
      }
    }
    return MergeStream(streams);
  }

  Future<String> getLyrics(String? songPath) async {
    if (songPath == null || songPath.isEmpty) {
      return "";
    }
    try {
      String lyricsPath =
          '${songPath.split('.').sublist(0, songPath.split('.').length - 1).join('.')}.lrc';
      if (File(lyricsPath).existsSync()) {
        String lyricsContent = await File(lyricsPath).readAsString();
        if (lyricsContent.isNotEmpty) {
          return lyricsContent;
        }
      } else {
        debugPrint("Lyrics file not found at $lyricsPath");
      }
    } catch (e) {
      debugPrint("Error fetching lyrics: $e");
    }
    return "";
  }

  Future<File> createWorkaroundFile(Song? song) async {
    if (song == null) {
      throw Exception("Song is null");
    }

    final String dir = (await getApplicationCacheDirectory()).path;
    final String path = '$dir/${song.album.target?.name ?? song.name}.png';
    final File file = File(path);
    if (file.existsSync()) {
      return file;
    }
    final ByteData data = ByteData.view(song.coverArt.buffer);
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  static bool fileExists(String path) {
    return File(path).existsSync();
  }

  static void exportPlaylist(String filePath, List<String> paths) {
    var file = File(filePath);
    file.writeAsStringSync("#EXTM3U\n");
    for (var song in paths) {
      file.writeAsStringSync('$song\n', mode: FileMode.append);
    }
  }
}
