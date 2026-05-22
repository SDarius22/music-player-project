import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';

class _FakeAlbumService extends Fake implements AlbumService {
  Album? albumToReturn;
  ({List<Album> content, int totalPages, int page}) pageResult = (
    content: const <Album>[],
    totalPages: 1,
    page: 0,
  );
  PageResult<Song> songsPageResult = const PageResult(
    content: <Song>[],
    totalPages: 1,
    page: 0,
  );

  @override
  Future<Album?> fetchAlbumDetails(String albumHash) async => albumToReturn;

  @override
  Future<({List<Album> content, int totalPages, int page})> getAlbumsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size,
  ) async => pageResult;

  @override
  Future<PageResult<Song>> getAlbumSongsPage(
    String albumHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async => songsPageResult;
}

class _FakeArtistService extends Fake implements ArtistService {
  Artist? artistToReturn;
  ({List<Artist> content, int totalPages, int page}) pageResult = (
    content: const <Artist>[],
    totalPages: 1,
    page: 0,
  );
  PageResult<Song> songsPageResult = const PageResult(
    content: <Song>[],
    totalPages: 1,
    page: 0,
  );

  @override
  Future<Artist?> fetchArtistDetails(String artistHash) async => artistToReturn;

  @override
  Future<({List<Artist> content, int totalPages, int page})> getArtistsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size,
  ) async => pageResult;

  @override
  Future<PageResult<Song>> getArtistSongsPage(
    String artistHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async => songsPageResult;
}

class _FakePlaylistService extends Fake implements PlaylistService {
  ({List<Playlist> content, int totalPages, int page}) pageResult = (
    content: const <Playlist>[],
    totalPages: 1,
    page: 0,
  );
  PageResult<Song> songsPageResult = const PageResult(
    content: <Song>[],
    totalPages: 1,
    page: 0,
  );
  Playlist? detailsToReturn;
  ({List<Playlist> content, int totalPages, int page}) indestructibleResult = (
    content: const <Playlist>[],
    totalPages: 1,
    page: 0,
  );
  ({List<Playlist> content, int totalPages, int page}) normalResult = (
    content: const <Playlist>[],
    totalPages: 1,
    page: 0,
  );

  @override
  Future<({List<Playlist> content, int totalPages, int page})> getPlaylistsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size,
  ) async => pageResult;

  @override
  Future<PageResult<Song>> getPlaylistSongsPageByHash(
    String playlistHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async => songsPageResult;

  @override
  Future<Playlist> getPlaylistDetails(Playlist playlist) async =>
      detailsToReturn!;

  @override
  Future<Playlist> addPlaylist(
    String name,
    List<Song> songs,
    Uint8List? coverArt,
  ) async => Playlist(name, songs: songs);

  @override
  Future<void> deletePlaylist(Playlist playlist) async {}

  @override
  Future<Playlist> addToPlaylist(Playlist playlist, List<Song> songs) async =>
      playlist;

  @override
  Future<void> deleteFromPlaylist(Song song, Playlist playlist) async {}

  @override
  Future<({List<Playlist> content, int totalPages, int page})>
  getIndestructiblePlaylists(int page, int size) async => indestructibleResult;

  @override
  Future<({List<Playlist> content, int totalPages, int page})>
  getNormalPlaylists(int page, int size) async => normalResult;

  @override
  Future<PageResult<Song>> getPlaylistSongsPage(
    Playlist playlist, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async => songsPageResult;
}

class _FakeSongService extends Fake implements SongService {
  Map<String, dynamic> sortMap = const {'Title': null};
  Song? fetchedSong;
  Song? enrichedSong;
  PageResult<Song> pageResult = const PageResult(
    content: <Song>[],
    totalPages: 1,
    page: 0,
  );
  PageResult<Song> recommendationsResult = const PageResult(
    content: <Song>[],
    totalPages: 1,
    page: 0,
  );
  List<Song> forgotten = const [];
  List<Song> quickDial = const [];

  @override
  Map<String, dynamic> get sortFields => sortMap;

  @override
  Future<Song?> fetchSongByFileHash(String fileHash) async => fetchedSong;

  @override
  Future<Song> fullyFetchSong(Song song) async => enrichedSong ?? song;

  @override
  Future<PageResult<Song>> getSongsPage(
    String query,
    String sortField,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    bool ascending,
    bool localOnly,
    int page,
    int pageSize,
  ) async => pageResult;

  @override
  Future<PageResult<Song>> getRecommendations(int page, int size) async =>
      recommendationsResult;

  @override
  Future<List<Song>> getForgottenFavourites() async => forgotten;

  @override
  Future<List<Song>> getQuickDial() async => quickDial;

  @override
  Future<void> updateSong(Song song) async {}

  @override
  void deleteSong(Song song) {}
}

class _FakeScannerService extends Fake implements AbstractMusicScannerService {
  final _controller = StreamController<double>.broadcast();

  @override
  Stream<double> get progressStream => _controller.stream;

  void emit(double progress) {
    _controller.add(progress);
  }

  @override
  Future<void> performQuickScan() async {}

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  group('AlbumProvider', () {
    test('delegates fetchPage/fetchEntity/getSongsPage to service', () async {
      final service = _FakeAlbumService();
      final provider = AlbumProvider(service);
      final album = Album('a', 'Album A');
      final song = Song('s1');
      service.albumToReturn = album;
      service.pageResult = (content: [album], totalPages: 2, page: 1);
      service.songsPageResult = PageResult(
        content: [song],
        totalPages: 3,
        page: 0,
      );

      final page = await provider.fetchPage('', 'Name', true, false, 1, 10);
      final details = await provider.fetchEntity(album);
      final songs = await provider.getSongsPage('a', page: 0, size: 1);

      expect(page.content, [album]);
      expect(details, same(album));
      expect(songs.content, [song]);
    });
  });

  group('ArtistProvider', () {
    test('delegates fetchPage/fetchEntity/getSongsPage to service', () async {
      final service = _FakeArtistService();
      final provider = ArtistProvider(service);
      final artist = Artist('a', 'Artist A');
      final song = Song('s1');
      service.artistToReturn = artist;
      service.pageResult = (content: [artist], totalPages: 2, page: 1);
      service.songsPageResult = PageResult(
        content: [song],
        totalPages: 3,
        page: 0,
      );

      final page = await provider.fetchPage('', 'Name', true, false, 1, 10);
      final details = await provider.fetchEntity(artist);
      final songs = await provider.getSongsPage('a', page: 0, size: 1);

      expect(page.content, [artist]);
      expect(details, same(artist));
      expect(songs.content, [song]);
    });
  });

  group('PlaylistProvider', () {
    test('delegates query methods and refresh notifies listeners', () async {
      final service = _FakePlaylistService();
      final provider = PlaylistProvider(service);
      final playlist = Playlist('Queue')..serverId = 1;
      final song = Song('s1');
      service.pageResult = (content: [playlist], totalPages: 2, page: 1);
      service.songsPageResult = PageResult(
        content: [song],
        totalPages: 3,
        page: 0,
      );
      service.detailsToReturn = playlist;
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      final page = await provider.fetchPage('', 'Name', true, false, 1, 10);
      final details = await provider.fetchEntity(playlist);
      final songsByHash = await provider.getSongsPage(playlist.getHash());
      final songsByPlaylist = await provider.getPlaylistSongsPage(playlist);
      await provider.addPlaylist('P', [song], null);
      await provider.deletePlaylist(playlist);
      await provider.addSongsToPlaylist(playlist, [song]);
      await provider.deleteSongFromPlaylist(song, playlist);
      await provider.refresh();

      expect(page.content, [playlist]);
      expect(details, same(playlist));
      expect(songsByHash.content, [song]);
      expect(songsByPlaylist.content, [song]);
      expect(notifyCount, 5);
    });

    test(
      'passes through indestructible and normal playlist page methods',
      () async {
        final service = _FakePlaylistService();
        final provider = PlaylistProvider(service);
        final p1 = Playlist('A');
        final p2 = Playlist('B');
        service.indestructibleResult = (content: [p1], totalPages: 1, page: 0);
        service.normalResult = (content: [p2], totalPages: 2, page: 1);

        final a = await provider.getIndestructiblePlaylists(0, 10);
        final b = await provider.getNormalPlaylists(1, 10);

        expect(a.content, [p1]);
        expect(b.content, [p2]);
      },
    );
  });

  group('SongProvider', () {
    test(
      'delegates fetch/enrich/list methods and notifies on refresh',
      () async {
        final songService = _FakeSongService();
        final scanner = _FakeScannerService();
        addTearDown(scanner.dispose);
        final provider = SongProvider(songService, scanner);
        final song = Song('s1')..name = 'Song 1';
        final enriched =
            Song('s1')
              ..name = 'Song 1'
              ..fullyLoaded = true;
        songService.fetchedSong = song;
        songService.enrichedSong = enriched;
        songService.pageResult = PageResult(
          content: [song],
          totalPages: 2,
          page: 1,
        );
        songService.recommendationsResult = PageResult(
          content: [song],
          totalPages: 1,
          page: 0,
        );
        songService.forgotten = [song];
        songService.quickDial = [song];
        var notifyCount = 0;
        provider.addListener(() {
          notifyCount++;
        });

        final fetched = await provider.fetchEntity(song);
        final full = await provider.enrichSong(song);
        final page = await provider.fetchPage('', 'Title', true, false, 1, 10);
        final recs = await provider.fetchRecommendedSongs();
        final forgotten = await provider.fetchRediscoverSongs();
        final jumpBack = await provider.fetchJumpBackSongs();
        provider.removeSong(song);
        await provider.updateSong(song);
        await provider.refresh();
        provider.refreshSongs();

        expect(fetched, same(song));
        expect(full, same(enriched));
        expect(page.content, [song]);
        expect(recs, [song]);
        expect(forgotten, [song]);
        expect(jumpBack, [song]);
        expect(notifyCount, 4);
      },
    );

    test('listens to scanner progress and notifies listeners', () async {
      final songService = _FakeSongService();
      final scanner = _FakeScannerService();
      addTearDown(scanner.dispose);
      final provider = SongProvider(songService, scanner);
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      scanner.emit(0.5);
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 1);
    });

    test('getSongsPage throws unsupported error', () {
      final provider = SongProvider(_FakeSongService(), _FakeScannerService());

      expect(
        () => provider.getSongsPage('hash'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
