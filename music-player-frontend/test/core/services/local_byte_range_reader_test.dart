import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

void main() {
  const reader = FileLocalByteRangeReader();

  LocalTrack trackFor(String sourceUri) => LocalTrack(
    sourceKey: sourceUri,
    sourceUri: sourceUri,
    potentialIdentityKey: PotentialIdentity.create(
      title: 'Track',
      artist: 'Artist',
      durationInSeconds: 120,
    ),
    name: 'Track',
  );

  test('reads an exact byte range at the requested offset', () async {
    final directory = await Directory.systemTemp.createTemp('reader-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.flac');
    await file.writeAsBytes([0, 1, 2, 3, 4, 5, 6, 7]);
    final stat = await file.stat();

    final result = await reader.read(
      trackFor(file.path),
      const LocalByteRange(offset: 2, length: 3),
    );

    expect(result, isNotNull);
    expect(result!.bytes, [2, 3, 4]);
    expect(result.sourceStable, isTrue);
    expect(result.snapshot.size, stat.size);
    expect(
      result.snapshot.modifiedAt?.microsecondsSinceEpoch,
      stat.modified.microsecondsSinceEpoch,
    );
    expect(result.snapshot.supportsRandomAccess, isTrue);
  });

  test('accepts the manifest-derived final chunk length', () async {
    final directory = await Directory.systemTemp.createTemp('reader-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.flac');
    await file.writeAsBytes([0, 1, 2, 3, 4, 5, 6]);

    final result = await reader.read(
      trackFor(file.path),
      const LocalByteRange(offset: 4, length: 3),
    );

    expect(result, isNotNull);
    expect(result!.bytes, [4, 5, 6]);
  });

  test('supports a file:// URI form', () async {
    final directory = await Directory.systemTemp.createTemp('reader-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.flac');
    await file.writeAsBytes([9, 8, 7]);
    final uri = file.uri.toString();

    final result = await reader.read(
      trackFor(uri),
      const LocalByteRange(offset: 1, length: 2),
    );

    expect(result, isNotNull);
    expect(result!.bytes, [8, 7]);
  });

  test(
    'rejects ranges that exceed the file (short read / truncation)',
    () async {
      final directory = await Directory.systemTemp.createTemp('reader-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/song.flac');
      await file.writeAsBytes([1, 2, 3, 4]);

      final result = await reader.read(
        trackFor(file.path),
        const LocalByteRange(offset: 2, length: 4),
      );

      expect(result, isNull);
    },
  );

  test('rejects unsupported content and remote schemes', () async {
    expect(
      await reader.read(
        trackFor('content://media/external/audio/media/42'),
        const LocalByteRange(offset: 0, length: 4),
      ),
      isNull,
    );
    expect(
      await reader.read(
        trackFor('http://example.com/song.flac'),
        const LocalByteRange(offset: 0, length: 4),
      ),
      isNull,
    );
  });

  test('returns null for a missing file', () async {
    final directory = await Directory.systemTemp.createTemp('reader-');
    addTearDown(() => directory.delete(recursive: true));
    final missing = '${directory.path}/missing.flac';

    final result = await reader.read(
      trackFor(missing),
      const LocalByteRange(offset: 0, length: 4),
    );

    expect(result, isNull);
  });

  test('rejects invalid ranges', () async {
    final directory = await Directory.systemTemp.createTemp('reader-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/song.flac');
    await file.writeAsBytes([1, 2, 3, 4]);

    expect(
      await reader.read(
        trackFor(file.path),
        const LocalByteRange(offset: -1, length: 2),
      ),
      isNull,
    );
    expect(
      await reader.read(
        trackFor(file.path),
        const LocalByteRange(offset: 0, length: 0),
      ),
      isNull,
    );
  });

  test(
    'rejects a file replaced by a shorter one between source snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp('reader-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/song.flac');
      await file.writeAsBytes([1, 2, 3, 4, 5, 6]);

      final stable = await reader.read(
        trackFor(file.path),
        const LocalByteRange(offset: 0, length: 6),
      );
      expect(stable, isNotNull);

      await file.writeAsBytes([1, 2]);

      final mutated = await reader.read(
        trackFor(file.path),
        const LocalByteRange(offset: 0, length: 6),
      );
      expect(mutated, isNull);
    },
  );
}
