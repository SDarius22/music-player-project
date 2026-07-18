import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';

void main() {
  group('ChunkStat', () {
    test('calculates server offload from every non-server source', () {
      final stat = ChunkStat(
        songFileHash: 'song',
        songName: 'Song',
        localChunks: 20,
        localCachedChunks: 30,
        p2pChunks: 10,
        serverChunks: 40,
      );

      expect(stat.serverOffloadedChunks, 60);
      expect(stat.serverOffloadPercentage, 60);
      expect(stat.p2pPercentage, 10);
    });

    test('server offload is zero when no chunks were delivered', () {
      final stat = ChunkStat(songFileHash: 'song', songName: 'Song');

      expect(stat.serverOffloadedChunks, 0);
      expect(stat.serverOffloadPercentage, 0);
    });
  });

  group('Song', () {
    test('equality is based on fileHash', () {
      expect(Song('same-hash'), equals(Song('same-hash')));
      expect(Song('hash-a'), isNot(equals(Song('hash-b'))));
    });

    test('local and offline availability distinguish files from chunks', () {
      final local = Song('local-hash')..path = '/music/song.mp3';
      final remote = Song('remote-hash');
      final partial =
          Song('partial-hash')
            ..manifestChunkSize = 4
            ..manifestTotalBytes = 16
            ..chunkHashes = List<String>.filled(4, '0' * 64)
            ..cachedChunkCount = 1;
      final cached =
          Song('cached-hash')
            ..manifestChunkSize = 4
            ..manifestTotalBytes = 16
            ..chunkHashes = List<String>.filled(4, '0' * 64)
            ..cachedChunkCount = 4
            ..fullyCached = true;

      expect(local.isLocal, isTrue);
      expect(local.isPlayableOffline, isTrue);
      expect(remote.isLocal, isFalse);
      expect(remote.isPlayableOffline, isFalse);
      expect(partial.hasCachedChunks, isTrue);
      expect(partial.isLocal, isFalse);
      expect(partial.isPlayableOffline, isFalse);
      expect(cached.isFullyCached, isTrue);
      expect(cached.isPlayableOffline, isTrue);
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

    test('metadata helpers, colours, update, and diagnostics work', () {
      final artist = Artist('artist', 'Performer');
      final album = Album('album', 'Record')
        ..colors = const [Color(0xff123456)];
      final source =
          Song('hash')
            ..name = 'Title'
            ..durationInSeconds = 12
            ..trackNumber = 2
            ..discNumber = 3
            ..year = 2025
            ..path = '/tmp/song.mp3'
            ..fullyLoaded = true;
      source.artist.target = artist;
      source.album.target = album;
      final target = Song('hash')..updateFrom(source);

      expect(target.getName(), 'Title');
      expect(target.getSecondaryText(), 'Performer');
      expect(target.getHash(), 'hash');
      expect(target.getImageUrl(), '/songs/hash/cover');
      expect(target.getColors(), album.colors);
      expect(target.toString(), contains('Title'));
      expect(() => target.updateFrom(Song('other')), throwsArgumentError);
      target.album.target = null;
      expect(target.getColors(), isEmpty);
    });
  });

  group('Album', () {
    test('isLocal is true when at least one song is local', () {
      final album = Album('album-hash', 'Album');
      expect(album.isLocal, isFalse);

      final local = Song('local')..path = '/tmp/local.mp3';
      final remote = Song('remote');
      album.addSong(local);
      album.addSong(remote);
      expect(album.isLocal, isTrue);
    });

    test('sorts songs, replaces duplicates, and exposes metadata', () {
      final artist = Artist('artist', 'Artist');
      final album = Album('album', 'Album')..setArtist(artist);
      album.addSong(
        Song('b')
          ..name = 'Beta'
          ..discNumber = 2
          ..trackNumber = 1
          ..durationInSeconds = 20,
      );
      album.addSong(
        Song('a')
          ..name = 'Alpha'
          ..discNumber = 1
          ..trackNumber = 2
          ..durationInSeconds = 10,
      );
      album.addSong(
        Song('a')
          ..name = 'Replacement'
          ..discNumber = 1
          ..trackNumber = 1
          ..durationInSeconds = 15,
      );
      expect(album.getSongs().map((song) => song.name), [
        'Replacement',
        'Beta',
      ]);
      expect(album.getDurationInSeconds(), 35);
      expect(album.getSecondaryText(), 'Artist');
      expect(album.getHash(), 'album');
      expect(album.getImageUrl(), '/albums/album/cover');
      expect(album.toString(), contains('Album'));
    });
  });

  group('Artist', () {
    test('isLocal is true when at least one song is local', () {
      final artist = Artist('artist-hash', 'Artist');
      expect(artist.isLocal, isFalse);

      artist.addSong(Song('local')..path = '/tmp/local.mp3');
      expect(artist.isLocal, isTrue);

      artist.addSong(Song('remote'));
      expect(artist.isLocal, isTrue);
    });

    test(
      'getCoverArt returns own image first, then album cover from songs',
      () {
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
      },
    );
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

    test('insert, duplicate guard, metadata, art, and rename work', () {
      final playlist =
          Playlist('Old')
            ..serverId = 7
            ..imageBytes = Uint8List.fromList([4]);
      final a = Song('a')..durationInSeconds = 5;
      final b = Song('b')..durationInSeconds = 6;
      playlist.addSong(a);
      playlist.insertSongAt(b, 0);
      playlist.addSong(a);
      playlist.setName('New');
      expect(playlist.getSongs().map((song) => song.fileHash), ['b', 'a']);
      expect(playlist.getName(), 'New');
      expect(playlist.getSecondaryText(), '2 Songs');
      expect(playlist.getHash(), '7');
      expect(playlist.getImageUrl(), '/playlists/7/cover');
      expect(playlist.getCoverArt(), [4]);
      expect(playlist.toString(), contains('New'));
    });

    test('isLocal is true when at least one song is local', () {
      final playlist = Playlist('Queue');
      expect(playlist.isLocal, isFalse);

      playlist.addSong(Song('local')..path = '/tmp/local.mp3');
      expect(playlist.isLocal, isTrue);

      playlist.addSong(Song('remote'));
      expect(playlist.isLocal, isTrue);
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
        'autoPlay': true,
        'autoPlayRecommendationsPage': 3,
        'pitch': 0.5,
        'speed': 1.5,
        'volume': 0.8,
        'sliderInSeconds': 10,
      });

      expect(settings.repeat, isTrue);
      expect(settings.shuffle, isTrue);
      expect(settings.autoPlay, isTrue);
      expect(settings.autoPlayRecommendationsPage, 3);
      expect(settings.pitch, 0.5);
      expect(settings.speed, 1.5);
      expect(settings.volume, 0.8);
      expect(settings.sliderInSeconds, 10);
      expect(settings.playing, isFalse);
    });

    test('toJson omits transient playing field', () {
      final json = AudioSettings().toJson();
      expect(json.containsKey('playing'), isFalse);
      expect(json.containsKey('autoPlay'), isTrue);
    });

    test('fromJson defaults autoPlay to false when missing', () {
      final settings = AudioSettings.fromJson({});
      expect(settings.autoPlay, isFalse);
      expect(settings.autoPlayRecommendationsPage, 0);
    });
  });
}
