import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

class _AndroidMediaFileService extends AbstractFileService {
  _AndroidMediaFileService(this.songs);

  List<SongModel> songs;
  bool fail = false;

  @override
  List<String> get supportedAudioExtensions => const <String>[];

  @override
  Future<List<SongModel>> getAudioFiles(List<String>? songPlaces) async {
    if (fail) throw StateError('permission revoked');
    return songs;
  }

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
  SongModel row({String title = 'Song', int modified = 100, int id = 42}) =>
      SongModel({
        '_id': id,
        'title': title,
        'artist': 'Artist',
        'album': 'Album',
        'duration': 125000,
        '_size': 800,
        'date_modified': modified,
        'volume_name': 'external_primary',
      });

  test(
    'warm scan writes zero records; metadata and source changes are saved',
    () async {
      final repository = _CountingRepository();
      final files = _AndroidMediaFileService([row()]);
      final service = LocalTrackService(repository);
      final scanner = AndroidMusicScannerService(service, files);
      await scanner.performQuickScan();
      final track = repository.getAll().single;
      track
        ..contentHash = 'verified'
        ..resolvedSongHash = 'candidate'
        ..playCount = 3;
      repository.saved = 0;
      await scanner.performQuickScan();
      expect(repository.saved, 0);
      expect(track.contentHash, 'verified');
      files.songs = [row(title: 'Corrected title')];
      await scanner.performQuickScan();
      expect(repository.saved, 1);
      expect(track.name, 'Corrected title');
      files.songs = [row(title: 'Corrected title', modified: 101)];
      await scanner.performQuickScan();
      expect(track.contentHash, isNull);
      expect(track.resolvedSongHash, isNull);
      expect(track.playCount, 3);
    },
  );

  test(
    'failed query preserves availability; successful empty query only reconciles media',
    () async {
      final repository = _CountingRepository();
      final files = _AndroidMediaFileService([row()]);
      final service = LocalTrackService(repository);
      final scanner = AndroidMusicScannerService(service, files);
      final phases = <MusicScanPhase>[];
      final subscription = scanner.progressStream.listen(
        (p) => phases.add(p.phase),
      );
      addTearDown(subscription.cancel);
      await scanner.performQuickScan();
      service.saveMany([
        service.discover(
          sourceKey: '/import/song',
          sourceUri: '/import/song',
          fallbackTitle: 'Imported',
        ),
      ]);
      files.fail = true;
      await scanner.performQuickScan();
      await Future<void>.delayed(Duration.zero);
      expect(phases.last, MusicScanPhase.failed);
      expect(repository.getAll().every((t) => t.available), isTrue);
      files
        ..fail = false
        ..songs = [];
      await scanner.performQuickScan();
      expect(repository.getBySourceKey('android:42')!.available, isFalse);
      expect(repository.getBySourceKey('/import/song')!.available, isTrue);
    },
  );

  test(
    'invalid rows never reconcile a partial query and duplicate IDs save once',
    () async {
      final repository = _CountingRepository();
      final files = _AndroidMediaFileService([row(), row()]);
      final scanner = AndroidMusicScannerService(
        LocalTrackService(repository),
        files,
      );
      await scanner.performQuickScan();
      expect(repository.saved, 1);
      files.songs = [SongModel({})];
      await scanner.performQuickScan();
      expect(repository.getAll().single.available, isTrue);
    },
  );

  test(
    'Android scan imports MediaStore songs with a playable content URI',
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
      expect(track!.sourceUri, 'content://media/external/audio/media/42');
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

class _CountingRepository extends InMemoryLocalTrackRepository {
  int saved = 0;
  @override
  void saveMany(List<LocalTrack> tracks) {
    saved += tracks.length;
    super.saveMany(tracks);
  }
}
