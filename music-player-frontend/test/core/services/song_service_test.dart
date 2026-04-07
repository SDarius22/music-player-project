import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/data_sync_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

void main() {
  group('SongService', () {
    late SongService service;

    setUp(() {
      final auth = AuthService(baseUrl: 'http://localhost');
      service = SongService(
        InMemorySongRepository(),
        InMemoryArtistRepository(),
        InMemoryAlbumRepository(),
        SongRestClient(baseUrl: 'http://localhost', authService: auth),
        DataSyncClient(baseUrl: 'http://localhost', authService: auth),
      );
    });

    test('getOrCreateSongByFileHash returns the same entity for same hash', () {
      final first = service.getOrCreateSongByFileHash('song-hash');
      final second = service.getOrCreateSongByFileHash('song-hash');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(service.getSongCount(), 1);
    });

    test('getLocalSong validates empty hash', () {
      expect(() => service.getLocalSong(''), throwsArgumentError);
    });
  });
}
