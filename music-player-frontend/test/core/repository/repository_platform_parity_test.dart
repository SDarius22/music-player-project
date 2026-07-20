import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_album_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_artist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_song_repository.dart';

void main() {
  final objectBoxLibraryPath = _findObjectBoxLibrary();

  group(
    'web and native repository parity',
    () {
      late Directory objectBoxDirectory;
      late DynamicLibrary objectBoxLibrary;

      setUpAll(() {
        objectBoxLibrary = DynamicLibrary.open(objectBoxLibraryPath!);
        expect(objectBoxLibrary.providesSymbol('obx_version'), isTrue);
        objectBoxDirectory = Directory.systemTemp.createTempSync(
          'repository-parity-',
        );
        ObjectBox.store = Store(
          getObjectBoxModel(),
          directory: objectBoxDirectory.path,
        );
      });

      tearDown(() {
        ObjectBox.store.box<Playlist>().removeAll();
        ObjectBox.store.box<Album>().removeAll();
        ObjectBox.store.box<Artist>().removeAll();
        ObjectBox.store.box<Song>().removeAll();
        ObjectBox.store.box<LocalTrack>().removeAll();
      });

      tearDownAll(() {
        ObjectBox.store.close();
        objectBoxDirectory.deleteSync(recursive: true);
      });

      test('album filtering and ordering match', () {
        final memory = _albumSnapshot(InMemoryAlbumRepository());
        final objectBox = _albumSnapshot(ObjectBoxAlbumRepository());

        expect(memory.localCount, objectBox.localCount);
        expect(memory.local, objectBox.local);
        expect(memory.descending, objectBox.descending);
      });

      test('artist filtering and ordering match', () {
        final memory = _artistSnapshot(InMemoryArtistRepository());
        final objectBox = _artistSnapshot(ObjectBoxArtistRepository());

        expect(memory.localCount, objectBox.localCount);
        expect(memory.local, objectBox.local);
        expect(memory.descending, objectBox.descending);
      });

      test('playlist filtering, ordering, and Queue visibility match', () {
        final memory = _playlistSnapshot(
          InMemoryPlaylistRepository(),
          InMemorySongRepository(),
        );
        final objectBox = _playlistSnapshot(
          ObjectBoxPlaylistRepository(),
          ObjectBoxSongRepository(),
        );

        expect(memory.normal, objectBox.normal);
        expect(memory.normalCount, objectBox.normalCount);
        expect(memory.indestructible, objectBox.indestructible);
        expect(memory.all, objectBox.all);
        expect(memory.localCount, objectBox.localCount);
        expect(memory.local, objectBox.local);
        expect(memory.descending, objectBox.descending);
        expect(memory.normal, contains('Queue'));
        expect(memory.indestructible, contains('Queue'));
      });

      test('song filtering and ordering match', () {
        final memory = _songSnapshot(InMemorySongRepository());
        final objectBox = _songSnapshot(ObjectBoxSongRepository());

        expect(memory.localCount, objectBox.localCount);
        expect(memory.local, objectBox.local);
        expect(memory.descending, objectBox.descending);
      });

      test('local-track IDs and initial watch state match', () async {
        final memory = await _localTrackSnapshot(
          InMemoryLocalTrackRepository(),
        );
        final objectBox = await _localTrackSnapshot(
          ObjectBoxLocalTrackRepository(),
        );

        expect(memory.names, objectBox.names);
        expect(memory.idsAssigned, objectBox.idsAssigned);
        expect(memory.initialWatch, objectBox.initialWatch);
      });

      test(
        'native song repository supports its complete query contract',
        () async {
          final repository = ObjectBoxSongRepository();
          final artist = ObjectBoxArtistRepository().saveArtist(
            Artist('artist', 'Artist'),
          );
          final album = Album('album', 'Album')..setArtist(artist);
          ObjectBoxAlbumRepository().saveAlbum(album);

          Song song(String hash, String name, int track, {bool local = false}) {
            final value =
                Song(hash)
                  ..name = name
                  ..fullyLoaded = true
                  ..durationInSeconds = track * 10
                  ..year = 2020 + track
                  ..discNumber = track == 3 ? 2 : 1
                  ..trackNumber = track
                  ..path = local ? '/music/$hash.mp3' : null
                  ..lastPlayed = DateTime.utc(2026, 1, track)
                  ..playCount = track;
            value.artist.target = artist;
            value.album.target = album;
            return value;
          }

          final alpha = song('alpha', 'Alpha', 2, local: true)
            ..likedByUser = true;
          final beta = song('beta', 'Beta', 1);
          final gamma = song('gamma', 'Gamma', 3)..fullyCached = true;
          final unloaded = Song('unloaded')..name = 'Unloaded';
          repository.saveSongs([gamma, unloaded, alpha, beta]);

          expect(repository.sortFields.keys, ['Title', 'Duration', 'Year']);
          expect(repository.getSongCount('', false), 3);
          expect(repository.getSongCount('', true), 2);
          expect(repository.getSongByFileHash(''), isNull);
          expect(repository.getSongByFileHash('alpha')?.name, 'Alpha');
          expect(repository.getSongByLocalPath(''), isNull);
          expect(
            repository.getSongByLocalPath('/music/alpha.mp3')?.name,
            'Alpha',
          );
          expect(repository.getOrCreateSong('alpha').id, alpha.id);
          expect(repository.getOrCreateSong('new').id, isPositive);
          expect(repository.getMostRecentPlayedSong()?.name, 'Gamma');
          expect(
            repository.getRecentlyPlayedSongs(2).map((song) => song.name),
            ['Gamma', 'Alpha'],
          );
          expect(repository.getMostPlayedSongs(1).single.name, 'Gamma');
          expect(repository.getFavoriteSongs().single.name, 'Alpha');
          expect(
            repository
                .getSongsPaged('', 'Duration', false, false, 1, 1)
                .single
                .name,
            'Alpha',
          );
          expect(
            repository
                .getSongsPaged('', 'invalid', true, true, 0, 10)
                .map((song) => song.name),
            ['Alpha', 'Gamma'],
          );
          expect(repository.getAlbumSongCount('album', false), 3);
          expect(repository.getAlbumSongCount('album', true), 2);
          expect(
            repository
                .getAlbumSongsPaged('album', false, 0, 3)
                .map((song) => song.name),
            ['Beta', 'Alpha', 'Gamma'],
          );
          expect(repository.getAlbumSongsPaged('album', false, 9, 1), isEmpty);
          expect(repository.getArtistSongCount('artist', false), 3);
          expect(repository.getArtistSongCount('artist', true), 2);
          expect(
            repository
                .getArtistSongsPaged('artist', false, 0, 2)
                .map((song) => song.name),
            ['Alpha', 'Beta'],
          );
          expect(
            repository
                .getPlaylistSongsPaged(
                  ['gamma', 'alpha', 'missing'],
                  false,
                  0,
                  10,
                )
                .map((song) => song.name),
            ['Gamma', 'Alpha'],
          );
          expect(repository.getPlaylistSongCount(['gamma', 'alpha'], true), 2);
          expect(
            repository.getPlaylistSongsPaged(['alpha'], false, 5, 1),
            isEmpty,
          );
          expect(repository.getAllSongs().first.name, 'Alpha');

          alpha.name = 'Alpha Updated';
          repository.updateSong(alpha);
          beta.name = 'Beta Updated';
          gamma.name = 'Gamma Updated';
          repository.updateSongs([beta, gamma]);
          expect(repository.getSongByFileHash('beta')?.name, 'Beta Updated');
          repository.deleteSong(unloaded);
          expect(repository.getSongByFileHash('unloaded'), isNull);

          final initial = await repository.watchSongs().first;
          expect(initial, isNotEmpty);
          repository.clearAll();
          expect(repository.getAllSongs(), isEmpty);
        },
      );

      test('native catalog repositories support all CRUD and paging paths', () {
        final artistRepository = ObjectBoxArtistRepository();
        final albumRepository = ObjectBoxAlbumRepository();
        final artist = artistRepository.getOrCreateArtist('a', 'Alpha');
        expect(artistRepository.getOrCreateArtist('a', 'Alpha').id, artist.id);
        final zulu = artistRepository.saveArtist(
          Artist('z', 'Zulu')..hasOfflineSource = true,
        );
        expect(artistRepository.sortFields.keys, ['Name']);
        expect(artistRepository.getArtistByHash('z')?.name, 'Zulu');
        expect(artistRepository.getArtistCount('', false), 2);
        expect(artistRepository.getArtistCount('', true), 1);
        expect(
          artistRepository
              .getArtistsPaged('', 'invalid', false, false, 0, 1)
              .single
              .name,
          'Zulu',
        );
        zulu.requiresSync = true;
        artistRepository.updateArtist(zulu);

        final alphaAlbum = albumRepository.getOrCreateAlbum(
          'aa',
          'Alpha Album',
          artist,
        );
        expect(
          albumRepository.getOrCreateAlbum('aa', 'Alpha Album', artist).id,
          alphaAlbum.id,
        );
        final zuluAlbum =
            Album('zz', 'Zulu Album')
              ..setArtist(zulu)
              ..hasOfflineSource = true;
        albumRepository.saveAlbum(zuluAlbum);
        expect(albumRepository.sortFields.keys, ['Name']);
        expect(albumRepository.getAlbumByHash('zz')?.name, 'Zulu Album');
        expect(albumRepository.getAlbumCount('', false), 2);
        expect(albumRepository.getAlbumCount('', true), 1);
        expect(
          albumRepository
              .getAlbumsPaged('', 'invalid', false, false, 0, 1)
              .single
              .name,
          'Zulu Album',
        );
        zuluAlbum.duration = 42;
        albumRepository.updateAlbum(zuluAlbum);
        albumRepository.clearAll();
        artistRepository.clearAll();
        expect(albumRepository.getAlbumCount('', false), 0);
        expect(artistRepository.getArtistCount('', false), 0);
      });

      test('native playlist repository covers Queue, paging, and deletion', () {
        final repository = ObjectBoxPlaylistRepository();
        final song = ObjectBoxSongRepository().saveSong(
          Song('local')
            ..name = 'Local'
            ..fullyLoaded = true
            ..path = '/music/local.mp3',
        );
        final queue = repository.getOrCreatePlaylist('Queue')
          ..indestructible = true;
        repository.savePlaylist(queue);
        expect(repository.getOrCreatePlaylist('Queue').id, queue.id);
        final local = repository.savePlaylist(
          Playlist('Local', songs: [song])..createdAt = DateTime.utc(2024),
        );
        final remote = repository.savePlaylist(
          Playlist('Remote')..createdAt = DateTime.utc(2025),
        );

        expect(repository.sortFields.keys, ['Name', 'Created At']);
        expect(repository.getPlaylistByName('Local')?.id, local.id);
        expect(repository.getPlaylistCount('', false), 3);
        expect(repository.getPlaylistCount('', true), 1);
        expect(repository.getIndestructiblePlaylistCount(), 1);
        expect(
          repository.getIndestructiblePlaylists(0, 1).single.name,
          'Queue',
        );
        expect(repository.getNormalPlaylistCount(), 3);
        expect(repository.getNormalPlaylists(1, 1).single.name, 'Queue');
        expect(repository.getAllPlaylists().first.name, 'Queue');
        expect(
          repository
              .getPlaylistsPaged('', 'Created At', false, false, 1, 1)
              .single
              .name,
          'Remote',
        );
        expect(
          repository
              .getPlaylistsPaged('', 'invalid', true, true, 0, 10)
              .single
              .name,
          'Local',
        );
        repository.deletePlaylist(remote);
        expect(repository.getPlaylistByName('Remote'), isNull);

        final duplicate = repository.savePlaylist(Playlist('Local'));
        expect(duplicate.id, 0);
        repository.clearAll();
        expect(repository.getAllPlaylists(), isEmpty);
      });

      test(
        'native local-track repository covers lookups and bulk saves',
        () async {
          final repository = ObjectBoxLocalTrackRepository();
          final alpha = _track('alpha', 'Alpha');
          final beta = _track('beta', 'Beta');
          repository.save(alpha);
          repository.saveMany([beta]);

          expect(repository.getBySourceKey('alpha')?.name, 'Alpha');
          expect(repository.getAll().map((track) => track.name), [
            'Alpha',
            'Beta',
          ]);
          expect(await repository.watch().first, hasLength(2));
          repository.clearAll();
          expect(repository.getAll(), isEmpty);
        },
      );
    },
    skip:
        objectBoxLibraryPath == null
            ? 'Native ObjectBox library is unavailable in this environment.'
            : false,
  );

  test('web repositories satisfy the native behavior contract', () async {
    final albums = _albumSnapshot(InMemoryAlbumRepository());
    expect(albums.localCount, 1);
    expect(albums.local, ['Zulu']);
    expect(albums.descending, ['Zulu', 'Alpha']);

    final artists = _artistSnapshot(InMemoryArtistRepository());
    expect(artists.localCount, 1);
    expect(artists.local, ['Zulu']);
    expect(artists.descending, ['Zulu', 'Alpha']);

    final playlists = _playlistSnapshot(
      InMemoryPlaylistRepository(),
      InMemorySongRepository(),
    );
    expect(playlists.normal, ['Local', 'Queue', 'Remote']);
    expect(playlists.indestructible, ['Pinned', 'Queue']);
    expect(playlists.local, ['Local']);
    expect(playlists.descending, ['Queue', 'Pinned', 'Remote', 'Local']);

    final songs = _songSnapshot(InMemorySongRepository());
    expect(songs.localCount, 1);
    expect(songs.local, ['Zulu']);
    expect(songs.descending, ['Zulu', 'Alpha']);

    final tracks = await _localTrackSnapshot(InMemoryLocalTrackRepository());
    expect(tracks.idsAssigned, isTrue);
    expect(tracks.initialWatch, ['Alpha', 'Beta']);
  });
}

String? _findObjectBoxLibrary() {
  final candidates = <String>[
    if (Platform.isLinux) 'build/linux/x64/debug/bundle/lib/libobjectbox.so',
    if (Platform.isMacOS) 'build/macos/Build/Products/Debug/libobjectbox.dylib',
    if (Platform.isWindows) r'build\windows\x64\runner\Debug\objectbox.dll',
  ];
  for (final candidate in candidates) {
    final file = File(candidate).absolute;
    if (file.existsSync()) return file.path;
  }
  return null;
}

({int localCount, List<String> local, List<String> descending}) _albumSnapshot(
  AlbumRepository repository,
) {
  repository.saveAlbum(Album('remote', 'Alpha'));
  repository.saveAlbum(Album('local', 'Zulu')..hasOfflineSource = true);

  return (
    localCount: repository.getAlbumCount('', true),
    local:
        repository
            .getAlbumsPaged('', 'Name', true, true, 0, 20)
            .map((album) => album.name)
            .toList(),
    descending:
        repository
            .getAlbumsPaged('', 'Name', false, false, 0, 20)
            .map((album) => album.name)
            .toList(),
  );
}

({int localCount, List<String> local, List<String> descending}) _artistSnapshot(
  ArtistRepository repository,
) {
  repository.saveArtist(Artist('remote', 'Alpha'));
  repository.saveArtist(Artist('local', 'Zulu')..hasOfflineSource = true);

  return (
    localCount: repository.getArtistCount('', true),
    local:
        repository
            .getArtistsPaged('', 'Name', true, true, 0, 20)
            .map((artist) => artist.name)
            .toList(),
    descending:
        repository
            .getArtistsPaged('', 'Name', false, false, 0, 20)
            .map((artist) => artist.name)
            .toList(),
  );
}

({
  List<String> normal,
  int normalCount,
  List<String> indestructible,
  List<String> all,
  int localCount,
  List<String> local,
  List<String> descending,
})
_playlistSnapshot(
  PlaylistRepository repository,
  SongRepository songRepository,
) {
  final localSong =
      Song('local-song')
        ..name = 'Local Song'
        ..fullyLoaded = true
        ..path = '/music/local.mp3';
  songRepository.saveSong(localSong);

  repository.savePlaylist(Playlist('Queue')..indestructible = true);
  repository.savePlaylist(Playlist('Pinned')..indestructible = true);
  repository.savePlaylist(
    Playlist('Local', songs: [localSong])..createdAt = DateTime.utc(2024, 1, 1),
  );
  repository.savePlaylist(
    Playlist('Remote')..createdAt = DateTime.utc(2025, 1, 1),
  );

  return (
    normal:
        repository
            .getNormalPlaylists(0, 20)
            .map((playlist) => playlist.name)
            .toList(),
    normalCount: repository.getNormalPlaylistCount(),
    indestructible:
        repository
            .getIndestructiblePlaylists(0, 20)
            .map((playlist) => playlist.name)
            .toList(),
    all: repository.getAllPlaylists().map((playlist) => playlist.name).toList(),
    localCount: repository.getPlaylistCount('', true),
    local:
        repository
            .getPlaylistsPaged('', 'Name', true, true, 0, 20)
            .map((playlist) => playlist.name)
            .toList(),
    descending:
        repository
            .getPlaylistsPaged('', 'Name', false, false, 0, 20)
            .map((playlist) => playlist.name)
            .toList(),
  );
}

({int localCount, List<String> local, List<String> descending}) _songSnapshot(
  SongRepository repository,
) {
  repository.saveSong(
    Song('remote')
      ..name = 'Alpha'
      ..fullyLoaded = true
      ..durationInSeconds = 10,
  );
  repository.saveSong(
    Song('local')
      ..name = 'Zulu'
      ..fullyLoaded = true
      ..durationInSeconds = 20
      ..path = '/music/zulu.mp3',
  );

  return (
    localCount: repository.getSongCount('', true),
    local:
        repository
            .getSongsPaged('', 'Title', true, true, 0, 20)
            .map((song) => song.name)
            .toList(),
    descending:
        repository
            .getSongsPaged('', 'Duration', false, false, 0, 20)
            .map((song) => song.name)
            .toList(),
  );
}

Future<({List<String> names, bool idsAssigned, List<String> initialWatch})>
_localTrackSnapshot(LocalTrackRepository repository) async {
  final first = _track('first', 'Alpha');
  final second = _track('second', 'Beta');
  repository.save(first);
  repository.saveMany([second]);

  final initialWatch = await repository.watch().first;
  return (
    names: repository.getAll().map((track) => track.name).toList(),
    idsAssigned: first.id > 0 && second.id > 0,
    initialWatch: initialWatch.map((track) => track.name).toList(),
  );
}

LocalTrack _track(String key, String name) => LocalTrack(
  sourceKey: key,
  sourceUri: '/music/$key.mp3',
  potentialIdentityKey: key,
  name: name,
);
