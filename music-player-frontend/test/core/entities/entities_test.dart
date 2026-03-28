import 'dart:convert';
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

  group('Song.fromJson', () {
    test('parses all fields from JSON', () {
      final song = Song.fromJson({
        'id': 42,
        'name': 'Test Song',
        'durationInSeconds': 180,
        'trackNumber': 3,
        'discNumber': 1,
        'year': 2020,
        'artistId': 7,
        'albumId': 5,
      });

      expect(song.serverId, 42);
      expect(song.name, 'Test Song');
      expect(song.durationInSeconds, 180);
      expect(song.trackNumber, 3);
      expect(song.discNumber, 1);
      expect(song.year, 2020);
      expect(song.serverArtistId, 7);
      expect(song.serverAlbumId, 5);
      expect(song.fullyLoaded, isTrue);
      expect(song.id, 0);
      expect(song.path, '');
    });

    test('uses defaults when fields are absent', () {
      final song = Song.fromJson({});

      expect(song.serverId, -1);
      expect(song.name, 'Unknown Song');
      expect(song.durationInSeconds, 0);
      expect(song.trackNumber, 0);
      expect(song.discNumber, 0);
      expect(song.year, 0);
      expect(song.serverArtistId, 0);
      expect(song.serverAlbumId, 0);
    });
  });

  group('Song.toJson', () {
    test('serializes expected fields', () {
      final song = Song();
      song.id = 10;
      song.playCount = 5;
      song.likedByUser = true;
      final dt = DateTime(2024, 6, 1);
      song.lastPlayed = dt;

      final json = song.toJson();

      expect(json['songId'], 10);
      expect(json['playCountDelta'], 5);
      expect(json['likedByUser'], isTrue);
      expect(json['lastPlayed'], dt);
    });
  });

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

    test('server songs equal when same serverId (non -1)', () {
      final a = Song();
      a.serverId = 99;
      final b = Song();
      b.serverId = 99;
      expect(a, equals(b));
    });

    test('server songs not equal when serverId is -1', () {
      final a = Song();
      a.serverId = -1;
      final b = Song();
      b.serverId = -1;
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

    test('uses serverId hash when path is empty', () {
      final song = Song();
      song.serverId = 42;
      expect(song.hashCode, 42.hashCode);
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

  group('Album.fromJson', () {
    test('parses name and serverId', () {
      final album = Album.fromJson({'id': 7, 'name': 'Dark Side'});

      expect(album.serverId, 7);
      expect(album.name, 'Dark Side');
      expect(album.imageBytes, isNull);
      expect(album.id, 0);
    });

    test('uses defaults when fields absent', () {
      final album = Album.fromJson({});

      expect(album.serverId, -1);
      expect(album.name, 'Unknown Album');
    });

    test('decodes base64 photo into imageBytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final b64 = base64Encode(bytes);
      final album = Album.fromJson({'id': 1, 'name': 'Art', 'photo': b64});

      expect(album.imageBytes, equals(bytes));
    });

    test('null photo leaves imageBytes null', () {
      final album = Album.fromJson({'id': 1, 'name': 'Art', 'photo': null});
      expect(album.imageBytes, isNull);
    });
  });

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

  group('Artist.fromJson', () {
    test('parses name and serverId', () {
      final artist = Artist.fromJson({'id': 3, 'name': 'Led Zeppelin'});

      expect(artist.serverId, 3);
      expect(artist.name, 'Led Zeppelin');
      expect(artist.id, 0);
    });

    test('uses defaults when fields absent', () {
      final artist = Artist.fromJson({});

      expect(artist.serverId, -1);
      expect(artist.name, 'Unknown Artist');
    });
  });

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

  group('Playlist.fromJson', () {
    test('parses serverId, name, and songIds', () {
      final playlist = Playlist.fromJson({
        'id': 5,
        'name': 'Favorites',
        'songIds': [10, 20, 30],
      });

      expect(playlist.serverId, 5);
      expect(playlist.name, 'Favorites');
      expect(playlist.serverSongIds, equals([10, 20, 30]));
    });

    test('uses defaults when fields absent', () {
      final playlist = Playlist.fromJson({});

      expect(playlist.serverId, -1);
      expect(playlist.name, 'Unknown Playlist');
      expect(playlist.serverSongIds, isEmpty);
    });

    test('coerces numeric songIds', () {
      final playlist = Playlist.fromJson({
        'id': 1,
        'name': 'P',
        'songIds': [1.0, 2.0],
      });
      expect(playlist.serverSongIds, equals([1, 2]));
    });
  });

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
    test('returns empty list when songsIds is empty', () {
      expect(Playlist().songsList, isEmpty);
    });

    test('returns empty list when songsIds has no matching songs', () {
      final p = Playlist();
      p.songsIds = [999];
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

    test('coerces songPlaceIncludeSubfolders to int (handles non-int strings)', () {
      final settings = AppSettings.fromJson({
        'songPlaceIncludeSubfolders': ['1', 'x', '0'],
      });
      expect(settings.songPlaceIncludeSubfolders, equals([1, 0, 0]));
    });
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
      expect(restored.songPlaceIncludeSubfolders,
          equals(original.songPlaceIncludeSubfolders));
    });

    test('toJson contains all expected keys', () {
      final json = AppSettings().toJson();
      expect(json.keys, containsAll([
        'firstTime',
        'systemTray',
        'fullClose',
        'drawerOpen',
        'mainSongPlace',
        'songPlaces',
        'songPlaceIncludeSubfolders',
      ]));
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
      expect(json.keys, containsAll([
        'repeat',
        'shuffle',
        'pitch',
        'speed',
        'volume',
        'sliderInSeconds',
      ]));
    });
  });
}
