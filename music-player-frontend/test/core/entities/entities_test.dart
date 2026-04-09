import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';

void main() {
  group('Song', () {
    test('equality is based on fileHash', () {
      expect(Song('same-hash'), equals(Song('same-hash')));
      expect(Song('hash-a'), isNot(equals(Song('hash-b'))));
    });

    test('isLocal uses path presence', () {
      final local = Song('local-hash')..path = '/music/song.mp3';
      final remote = Song('remote-hash');

      expect(local.isLocal(), isTrue);
      expect(remote.isLocal(), isFalse);
    });

    test('getCoverArt falls back from album to artist', () {
      final album = Album('album-hash', 'Album')
        ..imageBytes = Uint8List.fromList([1, 2]);
      final artist = Artist('artist-hash', 'Artist')
        ..imageBytes = Uint8List.fromList([9, 8]);

      final song = Song('song-hash');
      song.album.target = album;
      song.artist.target = artist;
      expect(song.getCoverArt(), equals(album.imageBytes));

      song.album.target = null;
      expect(song.getCoverArt(), equals(artist.imageBytes));
    });
  });

  group('Album', () {
    test('addSong updates ordered song list and duration', () {
      final album = Album('album-hash', 'Album');
      final first = Song('s1')
        ..discNumber = 1
        ..trackNumber = 2
        ..durationInSeconds = 40;
      final second = Song('s2')
        ..discNumber = 1
        ..trackNumber = 1
        ..durationInSeconds = 20;

      album.addSong(first);
      album.addSong(second);

      expect(album.getSongs().map((s) => s.getHash()).toList(), ['s2', 's1']);
      expect(album.getDurationInSeconds(), 60);
    });

    test('isLocal is false when no songs or any song is remote', () {
      final album = Album('album-hash', 'Album');
      expect(album.isLocal(), isFalse);

      final local = Song('local')..path = '/tmp/local.mp3';
      final remote = Song('remote');
      album.addSong(local);
      album.addSong(remote);
      expect(album.isLocal(), isFalse);
    });
  });

  group('Artist', () {
    test('isLocal requires at least one local song and no remote songs', () {
      final artist = Artist('artist-hash', 'Artist');
      expect(artist.isLocal(), isFalse);

      artist.addSong(Song('local')..path = '/tmp/local.mp3');
      expect(artist.isLocal(), isTrue);

      artist.addSong(Song('remote'));
      expect(artist.isLocal(), isFalse);
    });

    test('getCoverArt returns own image first, then album cover from songs', () {
      final artist = Artist('artist-hash', 'Artist');
      artist.imageBytes = Uint8List.fromList([7, 7]);
      expect(artist.getCoverArt(), equals(artist.imageBytes));

      artist.imageBytes = null;
      final album = Album('album-hash', 'Album')
        ..imageBytes = Uint8List.fromList([3, 3]);
      final song = Song('song-hash');
      song.album.target = album;
      artist.addSong(song);

      expect(artist.getCoverArt(), equals(album.imageBytes));
    });
  });

  group('Playlist', () {
    test('add/remove/clear songs updates ordered list and duration', () {
      final playlist = Playlist('Queue');
      final a = Song('a')..durationInSeconds = 10;
      final b = Song('b')..durationInSeconds = 20;

      playlist.addSong(a);
      playlist.addSong(b);
      expect(playlist.getSongs().map((s) => s.getHash()).toList(), ['a', 'b']);
      expect(playlist.getDurationInSeconds(), 29);

      playlist.removeSong(a);
      expect(playlist.getSongs().single.getHash(), 'b');
      expect(playlist.getDurationInSeconds(), 19);

      playlist.clearSongs();
      expect(playlist.getSongs(), isEmpty);
      expect(playlist.getDurationInSeconds(), 0);
    });

    test('isLocal is false when empty and true only for all-local songs', () {
      final playlist = Playlist('Queue');
      expect(playlist.isLocal(), isFalse);

      playlist.addSong(Song('local')..path = '/tmp/local.mp3');
      expect(playlist.isLocal(), isTrue);

      playlist.addSong(Song('remote'));
      expect(playlist.isLocal(), isFalse);
    });
  });

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
  });

  group('AudioSettings', () {
    test('fromJson parses all fields', () {
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
      expect(settings.playing, isFalse);
    });

    test('toJson omits transient playing field', () {
      final json = AudioSettings().toJson();
      expect(json.containsKey('playing'), isFalse);
    });
  });
}
