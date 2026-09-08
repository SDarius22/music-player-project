import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/services/local_byte_range_reader.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/platforms/android/android_app.dart';
import 'package:music_player_frontend/platforms/android/services/android_local_byte_range_reader.dart';
import 'package:music_player_frontend/platforms/android/services/android_local_source_bridge.dart';
import 'package:music_player_frontend/platforms/android/services/android_media_item_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidLocalSourceBridge.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Object? response;
  late LocalTrack track;
  late AndroidLocalByteRangeReader reader;
  late _NoFileReads fileReader;

  setUp(() {
    calls = [];
    response = {
      'bytes': Uint8List.fromList([5, 6]),
      'size': 6,
      'modifiedAtMs': 100000,
      'sourceStable': true,
    };
    track =
        LocalTrack(
            sourceKey: 'android:42',
            sourceUri: 'content://media/external_primary/audio/media/42',
            potentialIdentityKey: 'candidate',
          )
          ..fileSize = 6
          ..modifiedAt = DateTime.fromMillisecondsSinceEpoch(100000);
    fileReader = _NoFileReads();
    reader = AndroidLocalByteRangeReader(fileReader: fileReader);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (response is PlatformException) throw response!;
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android composition selects native reader', () {
    expect(
      const AndroidApp().createLocalByteRangeReader(),
      isA<AndroidLocalByteRangeReader>(),
    );
  });

  test(
    'MediaStore snapshot uses 64-bit ID and volume without a filesystem path',
    () {
      final snapshot =
          AndroidMediaItemSnapshot.fromMediaStoreMap({
            '_id': 4294967297,
            'volume_name': 'ABCD-1234',
            '_size': 123456,
            'date_modified': 100,
            'duration': 249999,
            'title': 'Song',
          })!;
      expect(snapshot.sourceKey, 'android:4294967297');
      expect(
        snapshot.sourceUri,
        'content://media/ABCD-1234/audio/media/4294967297',
      );
      expect(snapshot.modifiedAt!.millisecondsSinceEpoch, 100000);
      expect(snapshot.durationInSeconds, 249);
      expect(AndroidMediaItemSnapshot.fromMediaStoreMap({'_id': -1}), isNull);
    },
  );

  test(
    'content range reads exact offsets and never touches filesystem adapter',
    () async {
      final result = await reader.read(
        track,
        const LocalByteRange(offset: 4, length: 2),
      );
      expect(result!.bytes, [5, 6]);
      expect(result.snapshot.sourceKey, track.sourceKey);
      expect(calls.single.method, 'readRange');
      expect(calls.single.arguments, {
        'sourceUri': track.sourceUri,
        'offset': 4,
        'length': 2,
      });
      expect(fileReader.calls, 0);
    },
  );

  for (final scenario in [
    'permission',
    'unsupported',
    'short',
    'mutated',
    'malformed',
  ]) {
    test('rejects $scenario native read', () async {
      response = switch (scenario) {
        'permission' => PlatformException(code: 'permission_denied'),
        'unsupported' => PlatformException(code: 'not_seekable'),
        'short' => {'bytes': Uint8List(1), 'sourceStable': true},
        'mutated' => {'bytes': Uint8List(2), 'sourceStable': false},
        _ => {'bytes': 'invalid', 'sourceStable': true},
      };
      expect(
        await reader.read(track, const LocalByteRange(offset: 4, length: 2)),
        isNull,
      );
    });
  }

  test('invalid or oversized range never crosses platform channel', () async {
    expect(
      await reader.read(track, const LocalByteRange(offset: -1, length: 2)),
      isNull,
    );
    expect(
      await reader.read(
        track,
        const LocalByteRange(offset: 0, length: 2 * 1024 * 1024),
      ),
      isNull,
    );
    expect(calls, isEmpty);
  });

  test(
    'file URI routes to filesystem reader rather than native channel',
    () async {
      track.sourceUri = 'file:///import/song.mp3';
      await reader.read(track, const LocalByteRange(offset: 0, length: 2));
      expect(fileReader.calls, 1);
      expect(calls, isEmpty);
    },
  );

  test('native bytes enter common manifest verification before use', () async {
    final repository =
        InMemoryLocalTrackRepository()..save(track..contentHash = 'asset');
    final service = LocalTrackService(repository)..byteRangeReader = reader;
    final manifest = ChunkManifestDto.fromJson({
      'fileHash': 'asset',
      'totalBytes': 6,
      'chunkSize': 4,
      'totalChunks': 2,
      'hashes': [
        sha256.convert([1, 2, 3, 4]).toString(),
        sha256.convert([5, 6]).toString(),
      ],
    });
    expect(
      await service.readVerifiedPotentialChunk(Song('asset'), manifest, 1),
      [5, 6],
    );
    response = {
      'bytes': Uint8List.fromList([9, 9]),
      'size': 6,
      'modifiedAtMs': 100000,
      'sourceStable': true,
    };
    expect(
      await service.readVerifiedPotentialChunk(Song('asset'), manifest, 1),
      isNull,
    );
  });
}

class _NoFileReads implements LocalByteRangeReader {
  int calls = 0;
  @override
  Future<LocalByteRangeResult?> read(
    LocalTrack track,
    LocalByteRange range,
  ) async {
    calls++;
    return null;
  }
}
