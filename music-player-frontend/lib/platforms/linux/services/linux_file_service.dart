import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/desktop_audio_metadata_reader.dart';

class LinuxFileService extends AbstractFileService {
  static final _logger = Logger('LinuxFileService');

  @override
  Future<List<File>> getAudioFiles(List<String>? songPlaces) async {
    if (songPlaces == null || songPlaces.isEmpty) {
      return [];
    }
    // Use a Queue for efficient directory traversal
    List<File> files = [];
    Queue<Directory> dirs = Queue<Directory>();
    for (String dir in songPlaces) {
      dirs.add(Directory(dir));
    }

    //List<MetadataType> newSongs = [];

    while (dirs.isNotEmpty) {
      final dir = dirs.removeFirst();
      await for (FileSystemEntity entity in dir.list(followLinks: false)) {
        if (entity is File && super.isSupportedAudioFile(entity.path)) {
          files.add(File(entity.path));
        } else if (entity is Directory) {
          dirs.add(Directory(entity.path));
        }
      }
    }
    return files;
  }

  @override
  Future<Uint8List?> getImage(dynamic path) async {
    try {
      var metadataVar = readMetadata(File(path), getImage: true);
      return metadataVar.pictures.isNotEmpty
          ? metadataVar.pictures[0].bytes
          : null;
    } catch (e) {
      _logger.warning('Error reading image metadata for $path', e);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async {
    return readDesktopAudioMetadata(path, withImage: withImage);
  }

  @override
  get supportedAudioExtensions => [
    'aac', // AAC (ADTS)
    'ape', // Monkey's Audio
    'aiff', // AIFF
    'aif', // Sometimes used as alternate for AIFF
    'flac', // FLAC
    'mp3', // MP3
    'mp4', // MP4 (audio, like M4A)
    'm4a', // M4A is common for audio-only MP4
    'mpc', // Musepack
    'opus', // Opus
    'ogg', // Ogg Vorbis
    'oga', // Audio-specific extension for Ogg (optional)
    'spx', // Speex
    'wav', // WAV
    'wv', // WavPack
  ];
}
