import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

Future<Map<String, dynamic>> readDesktopAudioMetadata(
  String path, {
  bool withImage = false,
}) {
  return Isolate.run(
    () => _readDesktopAudioMetadata((path: path, withImage: withImage)),
  );
}

Map<String, dynamic> _readDesktopAudioMetadata(
  ({String path, bool withImage}) request,
) {
  final path = request.path;
  try {
    final metadata = readMetadata(File(path), getImage: request.withImage);
    return {
      'path': path,
      'title': metadata.title ?? _fileName(path),
      'album': metadata.album ?? 'Unknown Album',
      'duration': metadata.duration?.inSeconds ?? 0,
      'trackNumber': metadata.trackNumber ?? 0,
      'artist': metadata.artist ?? 'Unknown Artist',
      'discNumber': metadata.discNumber ?? 0,
      'year': metadata.year?.year ?? 0,
      'image':
          metadata.pictures.isNotEmpty ? metadata.pictures.first.bytes : null,
      'lyricsPath': _lyricsPath(path),
    };
  } catch (_) {
    return {'path': path, 'title': _fileName(path)};
  }
}

String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

String _lyricsPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  final candidate = '${path.substring(0, dot)}.lrc';
  return File(candidate).existsSync() ? candidate : '';
}
