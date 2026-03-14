import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

class WebFileService extends AbstractFileService {
  @override
  List<String> get supportedAudioExtensions => const [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
    'wav',
  ];

  @override
  Future<List> getAudioFiles(List<String>? songPlaces) async {
    // No local scanning on web.
    return const [];
  }

  @override
  Future<Uint8List> getImage(dynamic path) async {
    // On web we don't have embedded cover art for local files.
    return Constants.logoBytes;
  }

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async {
    throw UnimplementedError(
      "WebFileService does not support retrieving song metadata from local files.",
    );
  }

  @override
  Future<File> createWorkaroundFile(Song? song) async {
    if (song == null) {
      throw Exception("Song is null");
    }

    // return a dummy file since we can't access the local file system on web
    return File('dummy');
  }
}
