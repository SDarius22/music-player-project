import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

class AndroidFileService extends AbstractFileService {
  static final _logger = Logger('AndroidFileService');

  final OnAudioQuery audioQuery = OnAudioQuery();

  @override
  Future<List<SongModel>> getAudioFiles(List<String>? songPlaces) async {
    var songs = await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return songs;
  }

  @override
  Future<Uint8List?> getImage(dynamic path) async {
    return await audioQuery.queryArtwork(path, ArtworkType.AUDIO, size: 1024);
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
