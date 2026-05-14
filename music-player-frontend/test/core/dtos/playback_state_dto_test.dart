import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';

void main() {
  group('PlaybackStateDto', () {
    test('fromJson parses OpenAPI fields correctly', () {
      final dto = PlaybackStateDto.fromJson({
        'positionSeconds': 45,
        'shuffle': true,
        'repeat': false,
        'autoPlay': true,
        'autoPlayRecommendationsPage': 4,
        'updatedAt': '2026-05-04T10:30:00Z',
      });

      expect(dto.positionSeconds, equals(45));
      expect(dto.positionMs, equals(45000));
      expect(dto.shuffle, isTrue);
      expect(dto.repeat, isFalse);
      expect(dto.autoPlay, isTrue);
      expect(dto.autoPlayRecommendationsPage, equals(4));
      expect(dto.updatedAt, DateTime.parse('2026-05-04T10:30:00Z'));
    });

    test('fromJson uses safe defaults when fields are absent', () {
      final dto = PlaybackStateDto.fromJson({});

      expect(dto.positionSeconds, equals(0));
      expect(dto.shuffle, isFalse);
      expect(dto.repeat, isFalse);
      expect(dto.autoPlay, isFalse);
      expect(dto.autoPlayRecommendationsPage, equals(0));
      expect(dto.updatedAt, isNull);
    });

    test('fromJson ignores unknown legacy fields when present', () {
      final dto = PlaybackStateDto.fromJson({
        'queueFileHashes': ['hash1'],
        'currentFileHash': 'hash1',
        'positionSeconds': 0,
        'shuffle': false,
        'repeat': false,
      });

      expect(dto.positionSeconds, equals(0));
      expect(dto.shuffle, isFalse);
      expect(dto.repeat, isFalse);
      expect(dto.autoPlay, isFalse);
      expect(dto.autoPlayRecommendationsPage, equals(0));
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
        positionSeconds: 5,
        shuffle: true,
        repeat: true,
        autoPlay: true,
        autoPlayRecommendationsPage: 2,
      );

      final json = dto.toJson();

      expect(json['positionSeconds'], equals(5));
      expect(json['shuffle'], isTrue);
      expect(json['repeat'], isTrue);
      expect(json['autoPlay'], isTrue);
      expect(json['autoPlayRecommendationsPage'], equals(2));
      expect(json.containsKey('queueFileHashes'), isFalse);
      expect(json.containsKey('currentFileHash'), isFalse);
      expect(json.containsKey('updatedAt'), isFalse);
    });

    test('toJson then fromJson is a lossless round-trip for API fields', () {
      const original = PlaybackStateDto(
        positionSeconds: 72,
        shuffle: true,
        repeat: false,
        autoPlay: true,
        autoPlayRecommendationsPage: 9,
      );

      final restored = PlaybackStateDto.fromJson(original.toJson());

      expect(restored.positionSeconds, equals(original.positionSeconds));
      expect(restored.shuffle, equals(original.shuffle));
      expect(restored.repeat, equals(original.repeat));
      expect(restored.autoPlay, equals(original.autoPlay));
      expect(
        restored.autoPlayRecommendationsPage,
        equals(original.autoPlayRecommendationsPage),
      );
    });

    test('positionMs getter mirrors positionSeconds', () {
      const dto = PlaybackStateDto(positionSeconds: 9);
      final json = dto.toJson();

      expect(dto.positionMs, equals(9000));
      expect(json['positionSeconds'], equals(9));
    });
  });
}
