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
