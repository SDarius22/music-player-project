import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_dto.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

void main() {
  group('PlaylistService', () {
    late InMemoryPlaylistRepository playlistRepo;
    late InMemorySongRepository songRepo;
    late PlaylistService service;

    setUp(() {
      playlistRepo = InMemoryPlaylistRepository();
      songRepo = InMemorySongRepository();
      service = PlaylistService(
        playlistRepo,
        songRepo,
        PlaylistRestClient(
          baseUrl: 'http://localhost',
          authService: AuthService(baseUrl: 'http://localhost'),
        ),
      );
    });

    test('constructor initializes indestructible playlists', () {
      final names =
          service
              .getIndestructiblePlaylists()
              .map((p) => p.getName())
              .toSet();

      expect(names, containsAll({'Queue', 'Favorites', 'Most Played', 'Recently Played'}));
    });

    test('addToPlaylist avoids duplicates', () {
      final playlist = Playlist('Custom');
      final song = Song('hash-1');

      service.addToPlaylist(playlist, [song, song]);

      expect(playlist.getSongs(), hasLength(1));
      expect(playlist.getSongs().single.getHash(), 'hash-1');
    });

    test('cacheServerPlaylist creates/reuses playlist and links songs', () {
      final cached = service.cacheServerPlaylist(
        PlaylistDto(
          id: 42,
          name: 'Server PL',
          songFileHashes: ['a', 'b'],
          hasCover: false,
        ),
      );

      expect(cached.serverId, 42);
      expect(cached.getSongs().map((s) => s.getHash()).toSet(), {'a', 'b'});
      expect(playlistRepo.getPlaylistByServerIdAndName(42, 'Server PL'), isNotNull);
    });
  });
}
