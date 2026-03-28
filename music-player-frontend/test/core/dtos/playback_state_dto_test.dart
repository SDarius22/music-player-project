import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';

void main() {
  group('PlaybackStateDto', () {
    test('fromJson parses all fields correctly', () {
      final dto = PlaybackStateDto.fromJson({
        'queueSongIds': [1, 2, 3],
        'currentSongId': 2,
        'positionMs': 45000,
        'shuffle': true,
        'repeat': false,
      });

      expect(dto.queueSongIds, equals([1, 2, 3]));
      expect(dto.currentSongId, equals(2));
      expect(dto.positionMs, equals(45000));
      expect(dto.shuffle, isTrue);
      expect(dto.repeat, isFalse);
    });

    test('fromJson uses safe defaults when fields are absent', () {
      final dto = PlaybackStateDto.fromJson({});

      expect(dto.queueSongIds, isEmpty);
      expect(dto.currentSongId, isNull);
      expect(dto.positionMs, equals(0));
      expect(dto.shuffle, isFalse);
      expect(dto.repeat, isFalse);
    });

    test('fromJson handles explicit null for currentSongId', () {
      final dto = PlaybackStateDto.fromJson({
        'queueSongIds': [1],
        'currentSongId': null,
        'positionMs': 0,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.currentSongId, isNull);
    });

    test('fromJson coerces numeric types from JSON numbers', () {
      final dto = PlaybackStateDto.fromJson({
        'queueSongIds': [1.0, 2.0],
        'positionMs': 1000.0,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.queueSongIds, equals([1, 2]));
      expect(dto.positionMs, equals(1000));
    });

    test('toJson serialises all fields', () {
      const dto = PlaybackStateDto(
        queueSongIds: [10, 20],
        currentSongId: 10,
        positionMs: 5000,
        shuffle: true,
        repeat: true,
      );

      final json = dto.toJson();

      expect(json['queueSongIds'], equals([10, 20]));
      expect(json['currentSongId'], equals(10));
      expect(json['positionMs'], equals(5000));
      expect(json['shuffle'], isTrue);
      expect(json['repeat'], isTrue);
    });

    test('toJson includes null currentSongId key', () {
      const dto = PlaybackStateDto(queueSongIds: [], positionMs: 0);
      final json = dto.toJson();

      expect(json.containsKey('currentSongId'), isTrue);
      expect(json['currentSongId'], isNull);
    });

    test('toJson then fromJson is a lossless round-trip', () {
      const original = PlaybackStateDto(
        queueSongIds: [100, 200, 300],
        currentSongId: 200,
        positionMs: 72000,
        shuffle: true,
        repeat: false,
      );

      final restored = PlaybackStateDto.fromJson(original.toJson());

      expect(restored.queueSongIds, equals(original.queueSongIds));
      expect(restored.currentSongId, equals(original.currentSongId));
      expect(restored.positionMs, equals(original.positionMs));
      expect(restored.shuffle, equals(original.shuffle));
      expect(restored.repeat, equals(original.repeat));
    });
  });
}
