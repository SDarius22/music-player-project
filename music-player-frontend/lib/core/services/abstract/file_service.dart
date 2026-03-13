import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:watcher/watcher.dart';

abstract class AbstractFileService {
  List<String> get supportedAudioExtensions;

  bool isSupportedAudioFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return supportedAudioExtensions.contains(extension);
  }

  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  });

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

  Future<List> getAudioFiles(List<String>? songPlaces);

  Future<Uint8List> getImage(dynamic path);

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

  String getLyrics(String? songPath) {
    if (songPath == null || songPath.isEmpty) {
      return "";
    }
    try {
      String lyricsPath =
          '${songPath.split('.').sublist(0, songPath.split('.').length - 1).join('.')}.lrc';
      if (File(lyricsPath).existsSync()) {
        String lyricsContent = File(lyricsPath).readAsStringSync();
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

  bool fileExists(String path) {
    return File(path).existsSync();
  }

  void exportPlaylist(String filePath, List<String> paths) {
    var file = File(filePath);
    file.writeAsStringSync("#EXTM3U\n");
    for (var song in paths) {
      file.writeAsStringSync('$song\n', mode: FileMode.append);
    }
  }
}
