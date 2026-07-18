import 'dart:async';

import 'package:music_player_frontend/core/dtos/albums/album_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_page_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/create_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/dtos/playlists/update_playlist_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_page_dto.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class FakeScanner implements AbstractMusicScannerService {
  final StreamController<MusicScanProgress> _progress =
      StreamController.broadcast();

  @override
  Stream<MusicScanProgress> get progressStream => _progress.stream;

  @override
  Future<void> performQuickScan() async {}

  @override
  Future<void> cancelScan() async {}

  Future<void> dispose() => _progress.close();
}

class FakeSongRestClient extends SongRestClient {
  FakeSongRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final Map<String, SongDto> songsByHash = {};
  final List<({String? query, String sort})> pageRequests = [];
  bool failSongPages = false;

  void seed(List<SongDto> songs) {
    for (final song in songs) {
      songsByHash[song.fileHash] = song;
    }
  }

  SongDto dtoFor(String fileHash) {
    final song = songsByHash[fileHash];
    if (song == null) {
      throw StateError('No fake song registered for $fileHash');
    }
    return song;
  }

  @override
  Future<SongDto> getServerSong(String fileHash) async => dtoFor(fileHash);

  @override
  Future<SongPageDto> getSongsPage({
    String? query,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    int page = 0,
    int size = 50,
    String sort = 'name,asc',
  }) async {
    pageRequests.add((query: query, sort: sort));
    if (failSongPages) {
      throw Exception('song page unavailable');
    }

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final content =
        songsByHash.values
            .where((song) => song.name.toLowerCase().contains(normalizedQuery))
            .toList();
    final parts = sort.split(',');
    final ascending = parts.length < 2 || parts[1] != 'desc';
    content.sort((a, b) {
      final result = a.name.compareTo(b.name);
      return ascending ? result : -result;
    });

    return _songPage(content, page: page, size: size);
  }
}

class FakeAlbumRestClient extends AlbumRestClient {
  FakeAlbumRestClient(this.songClient)
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final FakeSongRestClient songClient;
  final Map<String, AlbumExpandedDto> albumsByHash = {};
  final List<({String? query, String sort})> pageRequests = [];
  final List<String> songPageRequests = [];
  bool failAlbumPages = false;
  bool failAlbumDetails = false;
  bool failAlbumSongPages = false;

  void seed(List<AlbumExpandedDto> albums) {
    for (final album in albums) {
      albumsByHash[album.hash] = album;
    }
  }

  @override
  Future<AlbumExpandedDto?> getAlbumByHash(String albumHash) async {
    if (failAlbumDetails) throw Exception('album detail unavailable');
    return albumsByHash[albumHash];
  }

  @override
  Future<AlbumPageDto> getAlbumsPage({
    String? query,
    int page = 0,
    int size = 30,
    String sort = 'name,asc',
  }) async {
    pageRequests.add((query: query, sort: sort));
    if (failAlbumPages) throw Exception('album page unavailable');

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final content =
        albumsByHash.values
            .where(
              (album) => album.name.toLowerCase().contains(normalizedQuery),
            )
            .toList();

    return AlbumPageDto(
      content: _page(content, page: page, size: size),
      page: page,
      size: size,
      totalPages: _totalPages(content.length, size),
      totalElements: content.length,
    );
  }

  @override
  Future<SongPageDto> getAlbumSongsPage({
    required String albumHash,
    int page = 0,
    int size = 50,
  }) async {
    songPageRequests.add(albumHash);
    if (failAlbumSongPages) throw Exception('album songs unavailable');

    final hashes = albumsByHash[albumHash]?.songFileHashes ?? const <String>[];
    final content = hashes.map(songClient.dtoFor).toList();
    return _songPage(content, page: page, size: size);
  }
}

class FakeArtistRestClient extends ArtistRestClient {
  FakeArtistRestClient(this.songClient)
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final FakeSongRestClient songClient;
  final Map<String, ArtistExpandedDto> artistsByHash = {};
  final List<({String? query, String sort})> pageRequests = [];
  final List<String> songPageRequests = [];
  bool failArtistPages = false;
  bool failArtistDetails = false;
  bool failArtistSongPages = false;

  void seed(List<ArtistExpandedDto> artists) {
    for (final artist in artists) {
      artistsByHash[artist.hash] = artist;
    }
  }

  @override
  Future<ArtistExpandedDto?> getArtistByHash(String artistHash) async {
    if (failArtistDetails) throw Exception('artist detail unavailable');
    return artistsByHash[artistHash];
  }

  @override
  Future<ArtistPageDto> getArtistsPage({
    String? query,
    int page = 0,
    int size = 30,
    String sort = 'name,asc',
  }) async {
    pageRequests.add((query: query, sort: sort));
    if (failArtistPages) throw Exception('artist page unavailable');

    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final content =
        artistsByHash.values
            .where(
              (artist) => artist.name.toLowerCase().contains(normalizedQuery),
            )
            .toList();

    return ArtistPageDto(
      content: _page(content, page: page, size: size),
      page: page,
      size: size,
      totalPages: _totalPages(content.length, size),
      totalElements: content.length,
    );
  }

  @override
  Future<SongPageDto> getArtistSongsPage({
    required String artistHash,
    int page = 0,
    int size = 50,
  }) async {
    songPageRequests.add(artistHash);
    if (failArtistSongPages) throw Exception('artist songs unavailable');

    final hashes =
        artistsByHash[artistHash]?.songFileHashes ?? const <String>[];
    final content = hashes.map(songClient.dtoFor).toList();
    return _songPage(content, page: page, size: size);
  }
}

class FakePlaylistRestClient extends PlaylistRestClient {
  FakePlaylistRestClient(this.songClient)
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  final FakeSongRestClient songClient;
  final Map<int, PlaylistExpandedDto> playlistsById = {};
  final List<int> songPageRequests = [];
  final List<int> updateRequests = [];
  final List<int> deleteRequests = [];
  int nextId = 100;
  CreatePlaylistDto? lastCreateRequest;
  UpdatePlaylistDto? lastUpdateRequest;
  bool failPlaylistSongPages = false;

  @override
  Future<PlaylistExpandedDto?> createPlaylist(
    CreatePlaylistDto createPlaylistDto,
  ) async {
    lastCreateRequest = createPlaylistDto;
    final orderedHashes = [...createPlaylistDto.playlistSongs]
      ..sort((a, b) => a.position.compareTo(b.position));
    final playlist = PlaylistExpandedDto(
      id: nextId++,
      name: createPlaylistDto.name,
      songFileHashes: orderedHashes.map((entry) => entry.songFileHash).toList(),
      indestructible: false,
      durationSeconds: 0,
    );
    playlistsById[playlist.id] = playlist;
    return playlist;
  }

  @override
  Future<PlaylistPageDto> getPlaylistsPage({
    String? query,
    bool? filterIndestructible,
    bool? includeQueue,
    int page = 0,
    int size = 50,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase() ?? '';
    final content =
        playlistsById.values
            .where(
              (playlist) =>
                  playlist.name.toLowerCase().contains(normalizedQuery),
            )
            .map(
              (playlist) => PlaylistDto(
                id: playlist.id,
                name: playlist.name,
                songFileHashes: playlist.songFileHashes,
                indestructible: playlist.indestructible,
              ),
            )
            .toList();

    return PlaylistPageDto(
      content: _page(content, page: page, size: size),
      page: page,
      size: size,
      totalPages: _totalPages(content.length, size),
      totalElements: content.length,
    );
  }

  @override
  Future<SongPageDto> getPlaylistSongsPage({
    required int playlistId,
    int page = 0,
    int size = 50,
  }) async {
    songPageRequests.add(playlistId);
    if (failPlaylistSongPages) {
      throw Exception('playlist song page unavailable');
    }

    final hashes = playlistsById[playlistId]?.songFileHashes ?? const [];
    final content = hashes.map(songClient.dtoFor).toList();
    return _songPage(content, page: page, size: size);
  }

  @override
  Future<bool> updatePlaylist(
    int playlistServerId,
    UpdatePlaylistDto updatePlaylistDto,
  ) async {
    updateRequests.add(playlistServerId);
    lastUpdateRequest = updatePlaylistDto;
    final existing = playlistsById[playlistServerId];
    if (existing == null) return false;

    final orderedHashes = [...?updatePlaylistDto.playlistSongs]
      ..sort((a, b) => a.position.compareTo(b.position));
    playlistsById[playlistServerId] = PlaylistExpandedDto(
      id: playlistServerId,
      name: updatePlaylistDto.name ?? existing.name,
      songFileHashes:
          orderedHashes.isEmpty
              ? existing.songFileHashes
              : orderedHashes.map((entry) => entry.songFileHash).toList(),
      indestructible: existing.indestructible,
      durationSeconds: existing.durationSeconds,
    );
    return true;
  }

  @override
  Future<bool> deletePlaylist(int playlistId) async {
    deleteRequests.add(playlistId);
    playlistsById.remove(playlistId);
    return true;
  }
}

class LibraryProviderHarness {
  LibraryProviderHarness({
    required this.songClient,
    required this.albumClient,
    required this.artistClient,
    required this.playlistClient,
    required this.songProvider,
    required this.albumProvider,
    required this.artistProvider,
    required this.playlistProvider,
    required this.songRepository,
    required this.albumRepository,
    required this.artistRepository,
  });

  final FakeSongRestClient songClient;
  final FakeAlbumRestClient albumClient;
  final FakeArtistRestClient artistClient;
  final FakePlaylistRestClient playlistClient;
  final SongProvider songProvider;
  final AlbumProvider albumProvider;
  final ArtistProvider artistProvider;
  final PlaylistProvider playlistProvider;
  final InMemorySongRepository songRepository;
  final InMemoryAlbumRepository albumRepository;
  final InMemoryArtistRepository artistRepository;
}

LibraryProviderHarness buildLibraryHarness(
  FakeScanner scanner, {
  List<SongDto> songs = const [],
  List<AlbumExpandedDto> albums = const [],
  List<ArtistExpandedDto> artists = const [],
}) {
  final songRepository = InMemorySongRepository();
  final artistRepository = InMemoryArtistRepository();
  final albumRepository = InMemoryAlbumRepository();
  final playlistRepository = InMemoryPlaylistRepository();
  final songClient = FakeSongRestClient()..seed(songs);
  final albumClient = FakeAlbumRestClient(songClient)..seed(albums);
  final artistClient = FakeArtistRestClient(songClient)..seed(artists);
  final playlistClient = FakePlaylistRestClient(songClient);

  final songService = SongService(
    songRepository,
    artistRepository,
    albumRepository,
    songClient,
  );
  final albumService = AlbumService(
    albumRepository,
    artistRepository,
    songRepository,
    albumClient,
  );
  final artistService = ArtistService(
    artistRepository,
    albumRepository,
    songRepository,
    artistClient,
  );
  final playlistService = PlaylistService(
    playlistRepository,
    playlistClient,
    songRepository,
    songService,
  );

  return LibraryProviderHarness(
    songClient: songClient,
    albumClient: albumClient,
    artistClient: artistClient,
    playlistClient: playlistClient,
    songProvider: SongProvider(songService, scanner),
    albumProvider: AlbumProvider(albumService),
    artistProvider: ArtistProvider(artistService),
    playlistProvider: PlaylistProvider(playlistService),
    songRepository: songRepository,
    albumRepository: albumRepository,
    artistRepository: artistRepository,
  );
}

SongDto songDto({
  required String hash,
  required String name,
  required String artist,
  required String album,
  String? artistHash,
  String? albumHash,
  int year = 2026,
}) {
  return SongDto(
    fileHash: hash,
    name: name,
    durationInSeconds: 180,
    trackNumber: 1,
    discNumber: 1,
    year: year,
    artist: ArtistDto(hash: artistHash ?? 'artist-$artist', name: artist),
    album: AlbumDto(hash: albumHash ?? 'album-$album', name: album),
    playCount: 0,
    likedByUser: false,
  );
}

AlbumExpandedDto albumDto({
  required String hash,
  required String name,
  required String artistHash,
  required String artistName,
  required List<String> songFileHashes,
}) {
  return AlbumExpandedDto(
    hash: hash,
    name: name,
    songFileHashes: songFileHashes,
    artist: ArtistDto(hash: artistHash, name: artistName),
    durationInSeconds: 0,
  );
}

ArtistExpandedDto artistDto({
  required String hash,
  required String name,
  required List<String> songFileHashes,
}) {
  return ArtistExpandedDto(
    hash: hash,
    name: name,
    songFileHashes: songFileHashes,
  );
}

SongPageDto _songPage(
  List<SongDto> content, {
  required int page,
  required int size,
}) {
  return SongPageDto(
    content: _page(content, page: page, size: size),
    page: page,
    size: size,
    totalPages: _totalPages(content.length, size),
    totalElements: content.length,
  );
}

List<T> _page<T>(List<T> content, {required int page, required int size}) {
  final start = page * size;
  final end = (start + size).clamp(0, content.length);
  return start >= content.length ? <T>[] : content.sublist(start, end);
}

int _totalPages(int length, int size) {
  return ((length + size - 1) ~/ size).clamp(1, 999999);
}
