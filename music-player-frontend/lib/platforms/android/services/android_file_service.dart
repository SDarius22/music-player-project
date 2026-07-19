import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class AndroidFileService extends AbstractFileService {
  static final _logger = Logger('AndroidFileService');

  final OnAudioQuery audioQuery = OnAudioQuery();
  final Map<String, int> _mediaIdsBySource = <String, int>{};

  @override
  Future<List<SongModel>> getAudioFiles(List<String>? songPlaces) async {
    var hasPermission = await audioQuery.permissionsStatus();
    if (!hasPermission) {
      hasPermission = await audioQuery.permissionsRequest();
    }
    if (!hasPermission) {
      throw StateError('Audio library permission was not granted');
    }
    final songs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
    );
    for (final song in songs) {
      _mediaIdsBySource['android:${song.id}'] = song.id;
      final data = song.data.toString().trim();
      if (data.isNotEmpty) _mediaIdsBySource[data] = song.id;
    }
    return songs;
  }

  @override
  Future<Uint8List?> getImage(dynamic path) async {
    final mediaId = _mediaIdFrom(path);
    if (mediaId == null) return null;
    return await audioQuery.queryArtwork(
      mediaId,
      ArtworkType.AUDIO,
      size: 1024,
    );
  }

  @override
  Future<File> createWorkaroundFile(Song? song) async {
    if (song == null) throw StateError('Song is null');
    final bytes =
        song.getCoverArt() ?? await getImage(song.localSourceKey ?? song.path);
    if (bytes == null || bytes.isEmpty) return File('');

    final directory = await getApplicationCacheDirectory();
    final key = song.album.target?.name ?? song.name;
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/notification_$safeKey.png');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  int? _mediaIdFrom(dynamic value) {
    if (value is int) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final mapped = _mediaIdsBySource[text];
    if (mapped != null) return mapped;
    final direct = int.tryParse(text.replaceFirst('android:', ''));
    if (direct != null) return direct;
    final uri = Uri.tryParse(text);
    return uri == null || uri.pathSegments.isEmpty
        ? null
        : int.tryParse(uri.pathSegments.last);
  }

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async {
    Map<String, dynamic>? metadataVariable = {};
    metadataVariable['path'] = path;

    AudioMetadata metadataVar;
    try {
      metadataVar = readMetadata(File(path), getImage: withImage);
    } catch (e) {
      _logger.warning('Error reading metadata for $path', e);
      metadataVariable['title'] = path.replaceAll("\\", "/").split("/").last;
      return metadataVariable;
    }
    metadataVariable['title'] =
        metadataVar.title ?? path.replaceAll("\\", "/").split("/").last;
    metadataVariable['album'] = metadataVar.album ?? "Unknown Album";
    metadataVariable['duration'] = metadataVar.duration?.inSeconds ?? 0;
    metadataVariable['trackNumber'] = metadataVar.trackNumber ?? 0;
    metadataVariable['artist'] = metadataVar.artist ?? "Unknown Artist";
    metadataVariable['discNumber'] = metadataVar.discNumber ?? 0;
    metadataVariable['year'] = metadataVar.year?.year ?? 0;
    metadataVariable['image'] =
        metadataVar.pictures.isNotEmpty ? metadataVar.pictures[0].bytes : null;
    metadataVariable['lyricsPath'] = super.getLyricsPath(path);
    return metadataVariable;
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
