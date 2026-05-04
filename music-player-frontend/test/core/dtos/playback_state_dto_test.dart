import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';

void main() {
  group('PlaybackStateDto', () {
    test('fromJson parses OpenAPI fields correctly', () {
      final dto = PlaybackStateDto.fromJson({
        'positionSeconds': 45,
        'shuffle': true,
        'repeat': false,
        'updatedAt': '2026-05-04T10:30:00Z',
      });

      expect(dto.positionSeconds, equals(45));
      expect(dto.positionMs, equals(45000));
      expect(dto.shuffle, isTrue);
      expect(dto.repeat, isFalse);
      expect(dto.updatedAt, DateTime.parse('2026-05-04T10:30:00Z'));
    });

    test('fromJson uses safe defaults when fields are absent', () {
      final dto = PlaybackStateDto.fromJson({});

      expect(dto.queueFileHashes, isEmpty);
      expect(dto.currentFileHash, isNull);
      expect(dto.positionSeconds, equals(0));
      expect(dto.shuffle, isFalse);
      expect(dto.repeat, isFalse);
      expect(dto.updatedAt, isNull);
    });

    test('fromJson keeps legacy queue/current fields when present', () {
      final dto = PlaybackStateDto.fromJson({
        'queueFileHashes': ['hash1'],
        'currentFileHash': 'hash1',
        'positionSeconds': 0,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.currentFileHash, equals('hash1'));
      expect(dto.queueFileHashes, equals(['hash1']));
    });

    test('fromJson falls back to legacy positionMs when needed', () {
      final dto = PlaybackStateDto.fromJson({
        'positionMs': 3200,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.positionSeconds, equals(3));
    });

    test('toJson serialises only OpenAPI request fields', () {
      const dto = PlaybackStateDto(
        queueFileHashes: ['hashA', 'hashB'],
        currentFileHash: 'hashA',
        positionSeconds: 5,
        shuffle: true,
        repeat: true,
      );

      final json = dto.toJson();

      expect(json['positionSeconds'], equals(5));
      expect(json['shuffle'], isTrue);
      expect(json['repeat'], isTrue);
      expect(json.containsKey('queueFileHashes'), isFalse);
      expect(json.containsKey('currentFileHash'), isFalse);
      expect(json.containsKey('updatedAt'), isFalse);
    });

    test('toJson then fromJson is a lossless round-trip for API fields', () {
      const original = PlaybackStateDto(
        positionSeconds: 72,
        shuffle: true,
        repeat: false,
      );

      final restored = PlaybackStateDto.fromJson(original.toJson());

      expect(restored.positionSeconds, equals(original.positionSeconds));
      expect(restored.shuffle, equals(original.shuffle));
      expect(restored.repeat, equals(original.repeat));
    });

    test('positionMs getter mirrors positionSeconds', () {
      const dto = PlaybackStateDto(positionSeconds: 9);
      final json = dto.toJson();

      expect(dto.positionMs, equals(9000));
      expect(json['positionSeconds'], equals(9));
    });
  });
}
