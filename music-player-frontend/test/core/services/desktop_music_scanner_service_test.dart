import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/desktop_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

class _FakeSettingsService extends Fake implements SettingsService {
  _FakeSettingsService(this.settings);

  final AppSettings settings;

  @override
  AppSettings getAppSettings() => settings;
}

class _BlockingFileService extends AbstractFileService {
  _BlockingFileService(this.files);

  final List<File> files;
  final metadataGate = Completer<void>();

  @override
  List<String> get supportedAudioExtensions => ['flac'];

  @override
  Future<List<File>> getAudioFiles(List<String>? songPlaces) async => files;

  @override
  Future<Uint8List?> getImage(dynamic path) async => null;

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) async {
    await metadataGate.future;
    return {
      'title': 'Enriched',
      'artist': 'Artist',
      'album': 'Album',
      'duration': 120,
      'trackNumber': 1,
      'discNumber': 1,
      'year': 2026,
    };
  }
}

void main() {
  test(
    'publishes playable discovery before metadata enrichment completes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fast-scan-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final files = <File>[];
      for (var index = 0; index < 3; index++) {
        final file = File('${directory.path}/song-$index.flac');
        await file.writeAsBytes([index]);
        files.add(file);
      }

      final repository = InMemoryLocalTrackRepository();
      final localTracks = LocalTrackService(repository);
      final fileService = _BlockingFileService(files);
      final settings = AppSettings()..songPlaces = [directory.path];
      final scanner = DesktopMusicScannerService(
        localTracks,
        fileService,
        _FakeSettingsService(settings),
        'TestScanner',
      );

      final scan = scanner.performQuickScan();
      while (repository.getAll().length != files.length) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(repository.getAll(), hasLength(3));
      expect(repository.getAll().every((track) => track.available), isTrue);
      expect(
        repository.getAll().every((track) => track.contentHash == null),
        isTrue,
      );
      expect(
        repository.getAll().every((track) => !track.metadataLoaded),
        isTrue,
      );

      fileService.metadataGate.complete();
      await scan;

      expect(
        repository.getAll().every((track) => track.metadataLoaded),
        isTrue,
      );
    },
  );
}
