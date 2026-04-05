import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';

void main() {
  // ─── Song ────────────────────────────────────────────────────────────────

  group('Song equality', () {
    test('local songs equal when same path', () {
      final a = Song()..path = '/music/song.mp3';
      final b = Song()..path = '/music/song.mp3';
      expect(a, equals(b));
    });

    test('local songs not equal when different path', () {
      final a = Song()..path = '/music/a.mp3';
      final b = Song()..path = '/music/b.mp3';
      expect(a, isNot(equals(b)));
    });

    test('cloud songs equal when same fileHash (non-empty)', () {
      final a = Song()..fileHash = 'hash99';
      final b = Song()..fileHash = 'hash99';
      expect(a, equals(b));
    });

    test('songs not equal when fileHash is empty and no path', () {
      final a = Song();
      final b = Song();
      expect(a, isNot(equals(b)));
    });

    test('local song not equal to non-Song object', () {
      final a = Song()..path = '/music/a.mp3';
      expect(a, isNot(equals('not a song')));
    });
  });

  group('Song.hashCode', () {
    test('uses path hash when path is non-empty', () {
      final song = Song()..path = '/music/song.mp3';
      expect(song.hashCode, '/music/song.mp3'.hashCode);
    });

    test('uses fileHash hash when fileHash is non-empty', () {
      final song = Song()..fileHash = 'hash42';
      expect(song.hashCode, 'hash42'.hashCode);
    });
  });

  group('Song.isLocal', () {
    test('returns true when path is non-empty', () {
      final song = Song()..path = '/music/song.mp3';
      expect(song.isLocal, isTrue);
    });

    test('returns false when path is empty', () {
      expect(Song().isLocal, isFalse);
    });
  });

  group('Song.colors', () {
    test('returns empty list when album is not set', () {
      expect(Song().colors, isEmpty);
    });
  });

  group('Song.coverArt', () {
    test('returns null when album not set', () {
      expect(Song().coverArt, isNull);
    });
  });

  // ─── Album ───────────────────────────────────────────────────────────────

  group('Album.durationInSeconds', () {
    test('returns 0 when no songs', () {
      expect(Album().durationInSeconds, 0);
    });

    test('caches computed duration', () {
      final album = Album();
      final d1 = album.durationInSeconds;
      final d2 = album.durationInSeconds;
      expect(d1, equals(d2));
    });
  });

  group('Album.isLocal', () {
    test('returns true when no songs', () {
      expect(Album().isLocal, isTrue);
    });
  });

  group('Album.coverArt', () {
    test('returns imageBytes', () {
      final album = Album();
      final bytes = Uint8List.fromList([0, 1]);
      album.imageBytes = bytes;
      expect(album.coverArt, equals(bytes));
    });
  });

  group('Album.toString', () {
    test('returns album name', () {
      final album = Album();
      album.name = 'Rumours';
      expect(album.toString(), 'Rumours');
    });
  });

  // ─── Artist ──────────────────────────────────────────────────────────────

  group('Artist.coverArt', () {
    test('returns null when no albums', () {
      expect(Artist().coverArt, isNull);
    });
  });

  group('Artist.isLocal', () {
    test('returns true when no songs', () {
      expect(Artist().isLocal, isTrue);
    });
  });

  group('Artist.toString', () {
    test('returns artist name', () {
      final artist = Artist();
      artist.name = 'Pink Floyd';
      expect(artist.toString(), 'Pink Floyd');
    });
  });

  // ─── Playlist ────────────────────────────────────────────────────────────

  group('Playlist.duration', () {
    test('returns 0 when no songs', () {
      expect(Playlist().duration, 0);
    });

    test('caches computed duration on second call', () {
      final p = Playlist();
      final d1 = p.duration;
      final d2 = p.duration;
      expect(d1, equals(d2));
    });
  });

  group('Playlist.isLocal', () {
    test('returns true when no songs', () {
      expect(Playlist().isLocal, isTrue);
    });
  });

  group('Playlist.songsList', () {
    test('returns empty list when songFileHashes is empty', () {
      expect(Playlist().songsList, isEmpty);
    });

    test('returns empty list when songFileHashes has no matching songs', () {
      final p = Playlist();
      p.songFileHashes = ['hash-999'];
      expect(p.songsList, isEmpty);
    });
  });

  group('Playlist.coverArt', () {
    test('returns imageBytes', () {
      final p = Playlist();
      final bytes = Uint8List.fromList([5, 6]);
      p.imageBytes = bytes;
      expect(p.coverArt, equals(bytes));
    });

    test('returns null when imageBytes not set', () {
      expect(Playlist().coverArt, isNull);
    });
  });

  // ─── AppSettings ─────────────────────────────────────────────────────────

  group('AppSettings.fromJson', () {
    test('parses all fields', () {
      final settings = AppSettings.fromJson({
        'firstTime': false,
        'systemTray': false,
        'fullClose': true,
        'drawerOpen': false,
        'mainSongPlace': '/home/music',
        'songPlaces': ['/a', '/b'],
        'songPlaceIncludeSubfolders': [1, 0],
      });

      expect(settings.firstTime, isFalse);
      expect(settings.systemTray, isFalse);
      expect(settings.fullClose, isTrue);
      expect(settings.drawerOpen, isFalse);
      expect(settings.mainSongPlace, '/home/music');
      expect(settings.songPlaces, equals(['/a', '/b']));
      expect(settings.songPlaceIncludeSubfolders, equals([1, 0]));
    });

    test('uses defaults when fields absent', () {
      final settings = AppSettings.fromJson({});

      expect(settings.firstTime, isTrue);
      expect(settings.systemTray, isTrue);
      expect(settings.fullClose, isFalse);
      expect(settings.drawerOpen, isTrue);
      expect(settings.mainSongPlace, '');
      expect(settings.songPlaces, isEmpty);
      expect(settings.songPlaceIncludeSubfolders, isEmpty);
    });

    test(
      'coerces songPlaceIncludeSubfolders to int (handles non-int strings)',
      () {
        final settings = AppSettings.fromJson({
          'songPlaceIncludeSubfolders': ['1', 'x', '0'],
        });
        expect(settings.songPlaceIncludeSubfolders, equals([1, 0, 0]));
      },
    );
  });

  group('AppSettings.toJson', () {
    test('round-trip through fromJson then toJson', () {
      final original = AppSettings();
      original.firstTime = false;
      original.systemTray = false;
      original.fullClose = true;
      original.drawerOpen = false;
      original.mainSongPlace = '/music';
      original.songPlaces = ['/a'];
      original.songPlaceIncludeSubfolders = [1];

      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.firstTime, original.firstTime);
      expect(restored.systemTray, original.systemTray);
      expect(restored.fullClose, original.fullClose);
      expect(restored.drawerOpen, original.drawerOpen);
      expect(restored.mainSongPlace, original.mainSongPlace);
      expect(restored.songPlaces, equals(original.songPlaces));
      expect(
        restored.songPlaceIncludeSubfolders,
        equals(original.songPlaceIncludeSubfolders),
      );
    });

    test('toJson contains all expected keys', () {
      final json = AppSettings().toJson();
      expect(
        json.keys,
        containsAll([
          'firstTime',
          'systemTray',
          'fullClose',
          'drawerOpen',
          'mainSongPlace',
          'songPlaces',
          'songPlaceIncludeSubfolders',
        ]),
      );
    });
  });

  // ─── AudioSettings ───────────────────────────────────────────────────────

  group('AudioSettings.fromJson', () {
    test('parses all fields', () {
      final settings = AudioSettings.fromJson({
        'repeat': true,
        'shuffle': true,
        'pitch': 0.5,
        'speed': 1.5,
        'volume': 0.8,
        'sliderInSeconds': 10,
      });

      expect(settings.repeat, isTrue);
      expect(settings.shuffle, isTrue);
      expect(settings.pitch, 0.5);
      expect(settings.speed, 1.5);
      expect(settings.volume, 0.8);
      expect(settings.sliderInSeconds, 10);
      expect(settings.playing, isFalse); // @Transient — never persisted
    });

    test('uses defaults when fields absent', () {
      final settings = AudioSettings.fromJson({});

      expect(settings.repeat, isFalse);
      expect(settings.shuffle, isFalse);
      expect(settings.pitch, 0.0);
      expect(settings.speed, 1.0);
      expect(settings.volume, 1.0);
      expect(settings.sliderInSeconds, 0);
    });

    test('coerces int pitch/speed/volume from JSON numbers', () {
      final settings = AudioSettings.fromJson({
        'pitch': 1,
        'speed': 2,
        'volume': 1,
      });
      expect(settings.pitch, isA<double>());
      expect(settings.speed, isA<double>());
      expect(settings.volume, isA<double>());
    });
  });

  group('AudioSettings.toJson', () {
    test('round-trip through fromJson then toJson', () {
      final original = AudioSettings();
      original.repeat = true;
      original.shuffle = true;
      original.pitch = 0.5;
      original.speed = 1.25;
      original.volume = 0.9;
      original.sliderInSeconds = 5;

      final json = original.toJson();
      final restored = AudioSettings.fromJson(json);

      expect(restored.repeat, original.repeat);
      expect(restored.shuffle, original.shuffle);
      expect(restored.pitch, original.pitch);
      expect(restored.speed, original.speed);
      expect(restored.volume, original.volume);
      expect(restored.sliderInSeconds, original.sliderInSeconds);
    });

    test('toJson does not include @Transient playing field', () {
      final json = AudioSettings().toJson();
      expect(json.containsKey('playing'), isFalse);
    });

    test('toJson contains all expected keys', () {
      final json = AudioSettings().toJson();
      expect(
        json.keys,
        containsAll([
          'repeat',
          'shuffle',
          'pitch',
          'speed',
          'volume',
          'sliderInSeconds',
        ]),
      );
    });
  });
}
