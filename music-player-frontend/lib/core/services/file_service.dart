import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
class FileService {
  static Future<String?> getLyrics(String songPath) async {
    try {
      String lyricsPath = '${songPath.split('.').sublist(0, songPath.split('.').length - 1).join('.')}.lrc';
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
    return null;
  }

  static Future<File> createWorkaroundFile(Uint8List bytes, int id) async {
    final ByteData data = ByteData.view(bytes.buffer);
    final String dir = (await getApplicationCacheDirectory()).path;
    final String path = '$dir/$id.jpeg';
    final File file = File(path);
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  static bool fileExists(String path) {
    return File(path).existsSync();
  }

  static void exportPlaylist(String fileName, List<String> paths) {
    var file = File(fileName);
    file.writeAsStringSync("#EXTM3U\n");
    for (var song in paths) {
      file.writeAsStringSync('$song\n', mode: FileMode.append);
    }
  }
}