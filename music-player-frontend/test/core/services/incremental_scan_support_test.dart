import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/incremental_scan_support.dart';

void main() {
  test('attachScannedPath preserves an existing ObjectBox identity', () {
    final existing = Song('hash')..id = 574;

    final result = attachScannedPath(existing, 'hash', '/music/song.flac');

    expect(result, same(existing));
    expect(result.id, 574);
    expect(result.path, '/music/song.flac');
  });

  test('scan decision skips unchanged files and initializes old records', () {
    final modified = DateTime(2026, 7, 18);
    final legacy = Song('legacy')..path = '/music/legacy.flac';
    final current =
        Song('current')
          ..path = '/music/current.flac'
          ..localFileSize = 42
          ..localFileModifiedAt = modified;

    expect(
      decideLocalFileScanAction(legacy, 42, modified),
      LocalFileScanAction.initializeStats,
    );
    expect(
      decideLocalFileScanAction(current, 42, modified),
      LocalFileScanAction.unchanged,
    );
    expect(
      decideLocalFileScanAction(current, 43, modified),
      LocalFileScanAction.hash,
    );
  });
}
