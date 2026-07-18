import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/entity_song_order.dart';

class _Provider implements QueryableProvider {
  _Provider(this.pages);

  final List<List<Song>> pages;

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async =>
      PageResult(content: pages[page], totalPages: pages.length, page: page);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SourceProvider implements QueryableProvider {
  _SourceProvider(this.sources);

  final Map<String, List<Song>> sources;
  final requested = <String>[];
  final requestedSizes = <int>[];

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async {
    requested.add(hash);
    requestedSizes.add(size);
    return PageResult(
      content: sources[hash] ?? const [],
      totalPages: 1,
      page: page,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song _song(
  String hash, {
  int disc = 1,
  int track = 1,
  int year = 2020,
  String album = 'Album',
}) {
  final song =
      Song(hash)
        ..name = hash
        ..discNumber = disc
        ..trackNumber = track
        ..year = year;
  song.album.target = Album('album-$album', album);
  return song;
}

void main() {
  test('loads every page and orders an album by disc then track', () async {
    final provider = _Provider([
      [_song('disc-2', disc: 2, track: 1), _song('track-2', track: 2)],
      [_song('track-1', track: 1)],
    ]);

    final songs = await EntitySongOrder.load(Album('album', 'Album'), provider);

    expect(songs.map((song) => song.fileHash), [
      'track-1',
      'track-2',
      'disc-2',
    ]);
  });

  test('orders an artist by album year, album, disc, and track', () async {
    final provider = _Provider([
      [
        _song('new', year: 2024, album: 'Later'),
        _song('old-2', track: 2, year: 2020, album: 'First'),
        _song('old-1', track: 1, year: 2020, album: 'First'),
      ],
    ]);

    final songs = await EntitySongOrder.load(
      Artist('artist', 'Artist'),
      provider,
    );

    expect(songs.map((song) => song.fileHash), ['old-1', 'old-2', 'new']);
  });

  test('preserves explicit playlist positions', () async {
    final playlist = Playlist('Playlist')
      ..songFileHashes = ['third', 'first', 'second'];
    final provider = _Provider([
      [_song('first'), _song('second'), _song('third')],
    ]);

    final songs = await EntitySongOrder.load(playlist, provider);

    expect(songs.map((song) => song.fileHash), ['third', 'first', 'second']);
  });

  test('loads local and remote sources for a merged album selection', () async {
    final album = Album('local-album:album', 'Album')
      ..remoteSourceHashes = ['remote-album'];
    final provider = _SourceProvider({
      'local-album:album': [_song('local', track: 1)],
      'remote-album': [_song('remote', track: 2)],
    });

    final songs = await EntitySongOrder.load(album, provider);

    expect(songs.map((song) => song.fileHash), ['local', 'remote']);
    expect(provider.requested, ['local-album:album', 'remote-album']);
    expect(provider.requestedSizes, everyElement(200));
  });
}
