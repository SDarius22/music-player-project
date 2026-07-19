import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

class _AndroidMediaFileService extends AbstractFileService {
  _AndroidMediaFileService(this.songs);

  final List<SongModel> songs;

  @override
  List<String> get supportedAudioExtensions => const <String>[];

  @override
  Future<List<SongModel>> getAudioFiles(List<String>? songPlaces) async =>
      songs;

  @override
  Future<Uint8List?> getImage(dynamic path) async => null;

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  test(
    'Android scan imports MediaStore songs using their data source',
    () async {
      final repository = InMemoryLocalTrackRepository();
      final scanner = AndroidMusicScannerService(
        LocalTrackService(repository),
        _AndroidMediaFileService(<SongModel>[
          SongModel(<String, dynamic>{
            '_id': 42,
            '_data': '/storage/emulated/0/Music/song.mp3',
            'title': 'Song title',
            'artist': 'Artist',
            'album': 'Album',
            'duration': 125000,
            'track': 3,
            'disc_number': '2',
            'year': 2026,
            'file_hash': '',
          }),
        ]),
      );

      await scanner.performQuickScan();

      final track = repository.getBySourceKey('android:42');
      expect(track, isNotNull);
      expect(track!.sourceUri, '/storage/emulated/0/Music/song.mp3');
      expect(track.name, 'Song title');
      expect(track.artistName, 'Artist');
      expect(track.albumName, 'Album');
      expect(track.durationInSeconds, 125);
      expect(track.trackNumber, 3);
      expect(track.discNumber, 2);
      expect(track.available, isTrue);
    },
  );
}
