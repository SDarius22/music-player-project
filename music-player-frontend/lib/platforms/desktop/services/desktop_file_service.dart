import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';

/// Common filesystem and metadata implementation for desktop clients.
class DesktopFileService extends AbstractFileService {
  static final _logger = Logger('DesktopFileService');

  @override
  Future<List<File>> getAudioFiles(List<String>? songPlaces) async {
    if (songPlaces == null || songPlaces.isEmpty) return [];
    final files = <File>[];
    final directories = Queue<Directory>.from(songPlaces.map(Directory.new));
    while (directories.isNotEmpty) {
      await for (final entity in directories.removeFirst().list(
        followLinks: false,
      )) {
        if (entity is File && isSupportedAudioFile(entity.path)) {
          files.add(entity);
        } else if (entity is Directory) {
          directories.add(entity);
        }
      }
    }
    return files;
  }

  @override
  Future<Uint8List?> getImage(dynamic path) async {
    try {
      final metadata = readMetadata(File(path), getImage: true);
      return metadata.pictures.isEmpty ? null : metadata.pictures.first.bytes;
    } catch (error) {
      _logger.warning('Error reading image metadata for $path', error);
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async {
    final result = <String, dynamic>{'path': path};
    AudioMetadata metadata;
    try {
      metadata = readMetadata(File(path), getImage: withImage);
    } catch (error) {
      _logger.warning('Error reading metadata for $path', error);
      result['title'] = _fileName(path);
      return result;
    }
    result
      ..['title'] = metadata.title ?? _fileName(path)
      ..['album'] = metadata.album ?? 'Unknown Album'
      ..['duration'] = metadata.duration?.inSeconds ?? 0
      ..['trackNumber'] = metadata.trackNumber ?? 0
      ..['artist'] = metadata.artist ?? 'Unknown Artist'
      ..['discNumber'] = metadata.discNumber ?? 0
      ..['year'] = metadata.year?.year ?? 0
      ..['image'] =
          metadata.pictures.isEmpty ? null : metadata.pictures.first.bytes
      ..['lyricsPath'] = getLyricsPath(path);
    return result;
  }

  String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

  @override
  List<String> get supportedAudioExtensions => const [
    'aac',
    'ape',
    'aiff',
    'aif',
    'flac',
    'mp3',
    'mp4',
    'm4a',
    'mpc',
    'opus',
    'ogg',
    'oga',
    'spx',
    'wav',
    'wv',
  ];
}
