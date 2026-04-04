import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';

void main() {
  group('PlaybackStateDto', () {
    test('fromJson parses all fields correctly', () {
      final dto = PlaybackStateDto.fromJson({
        'queueFileHashes': ['hash1', 'hash2', 'hash3'],
        'currentFileHash': 'hash2',
        'positionMs': 45000,
        'shuffle': true,
        'repeat': false,
      });

      expect(dto.queueFileHashes, equals(['hash1', 'hash2', 'hash3']));
      expect(dto.currentFileHash, equals('hash2'));
      expect(dto.positionMs, equals(45000));
      expect(dto.shuffle, isTrue);
      expect(dto.repeat, isFalse);
    });

    test('fromJson uses safe defaults when fields are absent', () {
      final dto = PlaybackStateDto.fromJson({});

      expect(dto.queueFileHashes, isEmpty);
      expect(dto.currentFileHash, isNull);
      expect(dto.positionMs, equals(0));
      expect(dto.shuffle, isFalse);
      expect(dto.repeat, isFalse);
    });

    test('fromJson handles explicit null for currentFileHash', () {
      final dto = PlaybackStateDto.fromJson({
        'queueFileHashes': ['hash1'],
        'currentFileHash': null,
        'positionMs': 0,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.currentFileHash, isNull);
    });

    test('fromJson coerces entries to strings', () {
      final dto = PlaybackStateDto.fromJson({
        'queueFileHashes': ['abc', 'def'],
        'positionMs': 1000,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.queueFileHashes, equals(['abc', 'def']));
      expect(dto.positionMs, equals(1000));
    });

    test('toJson serialises all fields', () {
      const dto = PlaybackStateDto(
        queueFileHashes: ['hashA', 'hashB'],
        currentFileHash: 'hashA',
        positionMs: 5000,
        shuffle: true,
        repeat: true,
      );

      final json = dto.toJson();

      expect(json['queueFileHashes'], equals(['hashA', 'hashB']));
      expect(json['currentFileHash'], equals('hashA'));
      expect(json['positionMs'], equals(5000));
      expect(json['shuffle'], isTrue);
      expect(json['repeat'], isTrue);
    });

    test('toJson includes null currentFileHash key', () {
      const dto = PlaybackStateDto(queueFileHashes: [], positionMs: 0);
      final json = dto.toJson();

      expect(json.containsKey('currentFileHash'), isTrue);
      expect(json['currentFileHash'], isNull);
    });

    test('toJson then fromJson is a lossless round-trip', () {
      const original = PlaybackStateDto(
        queueFileHashes: ['hash100', 'hash200', 'hash300'],
        currentFileHash: 'hash200',
        positionMs: 72000,
        shuffle: true,
        repeat: false,
      );

      final restored = PlaybackStateDto.fromJson(original.toJson());

      expect(restored.queueFileHashes, equals(original.queueFileHashes));
      expect(restored.currentFileHash, equals(original.currentFileHash));
      expect(restored.positionMs, equals(original.positionMs));
      expect(restored.shuffle, equals(original.shuffle));
      expect(restored.repeat, equals(original.repeat));
    });
  });
}
