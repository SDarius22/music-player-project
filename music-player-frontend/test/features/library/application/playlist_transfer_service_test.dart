import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/features/library/application/playlist_transfer_service.dart';
import 'package:music_player_frontend/features/library/domain/m3u_playlist.dart';

class _Songs extends Fake implements SongService {
  final Map<String, Song> byHash = {};
  final Map<String, Song> byPath = {};

  void add(Song song) {
    byHash[song.fileHash] = song;
    if (song.path != null) byPath[song.path!] = song;
  }

  @override
  Future<Song?> fetchSongByFileHash(String fileHash) async => byHash[fileHash];

  @override
  Song? getLocalSongByPath(String path) => byPath[path];

  @override
  List<Song> getAllLocalSongs() => byHash.values.toList();

  @override
  List<Song> getAllLocalCandidates() => byHash.values.toList();
}

Song _song(
  String hash,
  String title, {
  String? path,
  String artist = 'Artist',
  String album = 'Album',
  int duration = 120,
}) {
  final song =
      Song(hash)
        ..name = title
        ..path = path
        ..durationInSeconds = duration;
  song.artist.target = Artist('artist-$artist', artist);
  song.album.target = Album('album-$album', album);
  return song;
}

void main() {
  group('M3uPlaylistCodec', () {
    const codec = M3uPlaylistCodec();

    test('writes interoperable UTF-8 extended M3U metadata and paths', () {
      final bytes = codec.encode(
        playlistName: 'Road Trip',
        mode: M3uExportMode.compatible,
        entries: const [
          M3uEntry(
            location: r'C:\Music\track.mp3',
            durationInSeconds: 123,
            title: 'Track',
            artist: 'Artist',
            album: 'Album',
            fileHash: 'hash',
          ),
        ],
      );
      final text = utf8.decode(bytes);

      expect(text, startsWith('#EXTM3U\n#EXTENC:UTF-8\n'));
      expect(text, contains('#PLAYLIST:Road Trip'));
      expect(text, contains('#EXTINF:123,Artist - Track'));
      expect(text, contains('#EXTART:Artist'));
      expect(text, contains('#EXTALB:Album'));
      expect(text, contains(r'C:\Music\track.mp3'));
      expect(text, isNot(contains('#MPM-HASH')));
    });

    test('portable output includes a hash ignored by ordinary players', () {
      final text = utf8.decode(
        codec.encode(
          playlistName: 'Portable',
          mode: M3uExportMode.portable,
          entries: const [
            M3uEntry(
              location: 'music-player://song/abc',
              title: 'Remote',
              fileHash: 'abc',
            ),
          ],
        ),
      );

      expect(text, contains('#MPM-HASH:abc'));
      expect(text, contains('music-player://song/abc'));
    });

    test('parses BOM, CRLF, quoted paths, metadata, and unknown tags', () {
      final parsed = codec.decode(
        Uint8List.fromList(
          utf8.encode(
            '\ufeff#EXTM3U\r\n'
            '#PLAYLIST:Imported\r\n'
            '#EXTINF:125.4,Artist - Title\r\n'
            '#EXTART:Override Artist\r\n'
            '#EXTALB:Album\r\n'
            '#MPM-HASH:hash\r\n'
            '#UNKNOWN:ignored\r\n'
            '"../Music/track.mp3"\r\n'
            '/plain/path.flac\r\n',
          ),
        ),
      );

      expect(parsed.name, 'Imported');
      expect(parsed.entries, hasLength(2));
      expect(parsed.entries.first.location, '../Music/track.mp3');
      expect(parsed.entries.first.durationInSeconds, 125);
      expect(parsed.entries.first.artist, 'Override Artist');
      expect(parsed.entries.first.title, 'Title');
      expect(parsed.entries.first.album, 'Album');
      expect(parsed.entries.first.fileHash, 'hash');
      expect(parsed.entries.last.location, '/plain/path.flac');
      expect(parsed.entries.last.title, isNull);
    });

    test('accepts basic headerless M3U playlists', () {
      final parsed = codec.decode(
        Uint8List.fromList(utf8.encode('/one.mp3\n/two.flac\n')),
      );
      expect(parsed.entries.map((entry) => entry.location), [
        '/one.mp3',
        '/two.flac',
      ]);
    });
  });

  group('PlaylistTransferService', () {
    late _Songs songs;
    late PlaylistTransferService service;

    setUp(() {
      songs = _Songs();
      service = PlaylistTransferService(songs);
    });

    test('compatible export skips remote-only songs and sanitizes name', () {
      final local = _song('local', 'Local', path: '/music/local.mp3');
      final remote = _song('remote', 'Remote');
      final result = service.exportPlaylist(Playlist('Road/Trip'), [
        local,
        remote,
      ], M3uExportMode.compatible);

      expect(result.fileName, 'Road_Trip.m3u8');
      expect(result.exportedSongs, 1);
      expect(result.skippedSongs, [remote]);
      expect(utf8.decode(result.bytes), contains('/music/local.mp3'));
      expect(utf8.decode(result.bytes), isNot(contains('remote')));
    });

    test('portable export retains local paths and remote hashes', () {
      final local = _song('local', 'Local', path: '/music/local.mp3');
      final remote = _song('remote', 'Remote');
      final result = service.exportPlaylist(Playlist('Portable'), [
        local,
        remote,
      ], M3uExportMode.portable);
      final text = utf8.decode(result.bytes);

      expect(result.exportedSongs, 2);
      expect(result.skippedSongs, isEmpty);
      expect(text, contains('/music/local.mp3'));
      expect(text, contains('#MPM-HASH:remote'));
      expect(text, contains('music-player://song/remote'));
    });

    test('imports by hash, relative path, and file URI', () async {
      final hashed = _song('hash-song', 'Hashed');
      final relative = _song(
        'relative',
        'Relative',
        path: '/playlists/music/relative.mp3',
      );
      final fileUri = _song('uri', 'URI', path: '/music/uri.mp3');
      for (final song in [hashed, relative, fileUri]) {
        songs.add(song);
      }
      final content = '''#EXTM3U
#PLAYLIST:Recovered
#MPM-HASH:hash-song
music-player://song/hash-song
../music/relative.mp3
file:///music/uri.mp3
/not/found.mp3
''';

      final result = await service.importPlaylist(
        bytes: Uint8List.fromList(utf8.encode(content)),
        sourceName: 'fallback.m3u8',
        sourcePath: '/playlists/export/list.m3u8',
      );

      expect(result.playlistName, 'Recovered');
      expect(result.songs, [hashed, relative, fileUri]);
      expect(result.unresolvedEntries, hasLength(1));
      expect(result.unresolvedEntries.single.location, '/not/found.mp3');
    });

    test('imports a real-world playlist with accented paths without '
        'throwing', () async {
      final result = await service.importPlaylist(
        bytes: File('test/Eminem-newest.m3u').readAsBytesSync(),
        sourceName: 'Eminem-newest.m3u',
        sourcePath: '/playlists/Eminem-newest.m3u',
      );

      expect(result.playlistName, 'Eminem-newest');
      expect(result.songs, isEmpty);
      expect(result.unresolvedEntries, isNotEmpty);
    });

    test('matches songs by path suffix when the absolute prefix differs', () async {
      final renaissance = _song(
        'r',
        'Renaissance',
        path:
            '/home/darius/Music/Eminem - The Death of Slim Shady (Coup De Grâce)/01. Renaissance.flac',
      );
      final habits = _song(
        'h',
        'Habits',
        path:
            '/home/darius/Music/Eminem - The Death of Slim Shady (Coup De Grâce)/02. Habits.flac',
      );
      for (final song in [renaissance, habits]) {
        songs.add(song);
      }

      const dir =
          '/home/sala/Music/Music/Eminem - The Death of Slim Shady (Coup De Grâce)';
      final result = await service.importPlaylist(
        bytes: Uint8List.fromList(
          utf8.encode(
            '#EXTM3U\n'
            '$dir/01. Renaissance.flac\n'
            '$dir/02. Habits.flac\n',
          ),
        ),
        sourceName: 'Eminem-newest.m3u',
      );

      expect(result.songs, [renaissance, habits]);
      expect(result.unresolvedEntries, isEmpty);
    });

    test(
      'disambiguates identical file names by the longer path suffix',
      () async {
        final introA = _song('a', 'Intro', path: '/lib/Album A/01. Intro.flac');
        final introB = _song('b', 'Intro', path: '/lib/Album B/01. Intro.flac');
        songs.add(introA);
        songs.add(introB);

        final result = await service.importPlaylist(
          bytes: Uint8List.fromList(
            utf8.encode('#EXTM3U\n/elsewhere/Album B/01. Intro.flac\n'),
          ),
          sourceName: 'x.m3u',
        );

        expect(result.songs, [introB]);
        expect(result.unresolvedEntries, isEmpty);
      },
    );

    test('leaves entries unresolved when no local file path matches', () async {
      songs.add(_song('r', 'Renaissance', artist: 'Eminem', album: 'Album'));

      final result = await service.importPlaylist(
        bytes: Uint8List.fromList(
          utf8.encode(
            '#EXTM3U\n'
            '/home/sala/Music/Eminem/01. Renaissance.flac\n',
          ),
        ),
        sourceName: 'Eminem.m3u',
      );

      expect(result.songs, isEmpty);
      expect(result.unresolvedEntries, hasLength(1));
    });

    test('imports non-ASCII and percent-containing paths without '
        'throwing', () async {
      final accented = _song(
        'accented',
        'Renaissance',
        path: '/music/Coup De Grâce/01. Renaissance.flac',
      );
      final percent = _song(
        'percent',
        '100% Legit',
        path: '/music/100% Legit.mp3',
      );
      songs.add(accented);
      songs.add(percent);

      final result = await service.importPlaylist(
        bytes: Uint8List.fromList(
          utf8.encode(
            '#EXTM3U\n'
            '/music/COUP DE GRÂCE/01. RENAISSANCE.flac\n'
            '/music/100% LEGIT.mp3\n'
            '/music/Alfred’s Theme.flac\n',
          ),
        ),
        sourceName: 'Eminem-newest.m3u',
      );

      expect(result.playlistName, 'Eminem-newest');
      expect(result.songs, [accented, percent]);
      expect(result.unresolvedEntries, hasLength(1));
      expect(
        result.unresolvedEntries.single.location,
        '/music/Alfred’s Theme.flac',
      );
    });

    test('falls back to the source file name for the playlist name', () async {
      final result = await service.importPlaylist(
        bytes: Uint8List.fromList(
          utf8.encode('#EXTINF:-1,Artist - Duplicate\nunknown.mp3\n'),
        ),
        sourceName: 'My Mix.m3u',
      );

      expect(result.playlistName, 'My Mix');
      expect(result.songs, isEmpty);
      expect(result.unresolvedEntries, hasLength(1));
    });
  });
}
