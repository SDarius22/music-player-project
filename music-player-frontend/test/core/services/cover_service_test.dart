import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/cover_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/ui/components/widgets/cached_cover_image.dart';

class _Albums extends Fake implements AlbumService {
  final updated = <Album>[];

  @override
  void updateAlbum(Album album) => updated.add(album);
}

class _Artists extends Fake implements ArtistService {
  final updated = <Artist>[];

  @override
  void updateArtist(Artist artist) => updated.add(artist);
}

class _Files extends Fake implements AbstractFileService {
  @override
  Future<Uint8List?> getImage(dynamic path) async => Uint8List(0);
}

class _Songs extends Fake implements SongService {}

class _Playlists extends Fake implements PlaylistService {}

class _NoImage extends Fake implements BaseEntity {
  @override
  Uint8List? getCoverArt() => null;

  @override
  String getImageUrl() => '';
}

class _Auth extends AuthService {
  _Auth() : super(baseUrl: 'http://test');

  @override
  String? get accessToken => 'token';
}

void main() {
  late _Albums albums;
  late _Artists artists;
  late CoverService service;

  setUp(() {
    albums = _Albums();
    artists = _Artists();
    final auth = _Auth();
    service = CoverService(
      albumService: albums,
      songService: _Songs(),
      artistService: artists,
      playlistService: _Playlists(),
      fileService: _Files(),
      coverRestService: CoverRestClient(
        baseUrl: 'http://test',
        authService: auth,
      ),
      authService: auth,
    );
  });

  test('uses the create-playlist asset and existing local bytes', () {
    final create = Playlist('Create New Playlist')..indestructible = true;
    expect(service.getWidget(create), isA<Image>());

    final album = Album('album', 'Album')..imageBytes = Uint8List.fromList([1]);
    Uint8List? observed;
    expect(
      service.getWidget(album, onBytesLoaded: (bytes) => observed = bytes),
      isA<Image>(),
    );
    expect(observed, [1]);
  });

  test('returns a placeholder for an entity without an image URL', () {
    expect(service.getWidget(_NoImage()), isA<Container>());
  });

  test('builds authenticated remote images and persists album covers', () {
    final album = Album('album', 'Album');
    final widget = service.getWidget(album) as CachedCoverImage;
    expect(widget.imageUrl, 'http://test/albums/album/cover');
    expect(widget.headers['Authorization'], 'Bearer token');
    widget.onBytesLoaded!(Uint8List.fromList([2]));
    expect(album.imageBytes, [2]);
    expect(albums.updated, [album]);
    widget.onBytesLoaded!(Uint8List.fromList([3]));
    expect(albums.updated, hasLength(1));
  });

  test('persists artist and song album covers', () {
    final artist = Artist('artist', 'Artist');
    final artistWidget = service.getWidget(artist) as CachedCoverImage;
    artistWidget.onBytesLoaded!(Uint8List.fromList([4]));
    expect(artists.updated, [artist]);

    final album = Album('album', 'Album');
    final song = Song('song')..path = '/tmp/song.mp3';
    song.album.target = album;
    final songWidget = service.getWidget(song) as CachedCoverImage;
    expect(songWidget.path, '/tmp/song.mp3');
    songWidget.onBytesLoaded!(Uint8List.fromList([5]));
    expect(albums.updated, [album]);
  });

  test('song without an album still builds a remote widget', () {
    final widget = service.getWidget(Song('song')) as CachedCoverImage;
    expect(widget.onBytesLoaded, isNull);
  });
}
