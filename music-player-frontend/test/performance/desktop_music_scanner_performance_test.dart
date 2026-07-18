import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/services/desktop_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/platforms/linux/services/linux_file_service.dart';

class _FakeSettingsService extends Fake implements SettingsService {
  _FakeSettingsService(this.settings);

  final AppSettings settings;

  @override
  AppSettings getAppSettings() => settings;
}

class _MetadataBlockingLinuxFileService extends LinuxFileService {
  final metadataGate = Completer<void>();

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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'discovers and persists 1000 playable tracks within the performance budget',
    () async {
      const trackCount = 1000;
      const discoveryBudget = Duration(seconds: 20);
      final root = await Directory.systemTemp.createTemp(
        'scanner-performance-',
      );
      final musicDirectory = Directory('${root.path}/music')..createSync();
      for (var index = 0; index < trackCount; index++) {
        File(
          '${musicDirectory.path}/song-$index.flac',
        ).writeAsBytesSync([index & 0xff]);
      }

      addTearDown(() => root.deleteSync(recursive: true));

      final repository = InMemoryLocalTrackRepository();
      final localTracks = LocalTrackService(repository);
      final fileService = _MetadataBlockingLinuxFileService();
      final settings = AppSettings()..songPlaces = [musicDirectory.path];
      final scanner = DesktopMusicScannerService(
        localTracks,
        fileService,
        _FakeSettingsService(settings),
        'ScannerPerformanceTest',
      );
      final allTracksDiscovered = repository.watch().firstWhere(
        (tracks) => tracks.length == trackCount,
      );

      final stopwatch = Stopwatch()..start();
      final scan = scanner.performQuickScan();
      await allTracksDiscovered.timeout(discoveryBudget);
      stopwatch.stop();

      final elapsed = stopwatch.elapsed;
      final tracksPerSecond =
          trackCount * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
      debugPrint(
        'PERF scanner discovery: $trackCount tracks in '
        '${elapsed.inMilliseconds} ms '
        '(${tracksPerSecond.toStringAsFixed(1)} tracks/s)',
      );

      final discovered = repository.getAll();
      expect(discovered, hasLength(trackCount));
      expect(discovered.every((track) => track.available), isTrue);
      expect(discovered.every((track) => !track.metadataLoaded), isTrue);
      expect(discovered.every((track) => track.contentHash == null), isTrue);
      expect(
        elapsed,
        lessThan(discoveryBudget),
        reason:
            'Basic discovery must stay comfortably below the user-facing '
            '2-3 minute target for 1000 tracks.',
      );

      fileService.metadataGate.complete();
      await scan.timeout(const Duration(seconds: 20));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
