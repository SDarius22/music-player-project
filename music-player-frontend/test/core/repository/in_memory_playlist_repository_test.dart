import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';

void main() {
  group('InMemoryPlaylistRepository', () {
    test('getOrCreatePlaylist reuses playlist for same serverId and name', () {
      final repo = InMemoryPlaylistRepository();

      final first = repo.getOrCreatePlaylist(10, 'Favorites');
      final second = repo.getOrCreatePlaylist(10, 'Favorites');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getPlaylistByServerIdAndName(10, 'Favorites'), isNotNull);
    });

    test('watchPlaylists emits after save', () async {
      final repo = InMemoryPlaylistRepository();

      final future = repo.watchPlaylists().first as Future<List<Playlist>>;
      repo.savePlaylist(Playlist('Queue'));

      final emitted = await future;
      expect(emitted, isNotEmpty);
      expect(emitted.first.getName(), isNotEmpty);
    });

    test('indestructible and normal playlist filters work', () {
      final repo = InMemoryPlaylistRepository();
      final special = Playlist('Special')..indestructible = true;
      final regular = Playlist('Regular');
      repo.savePlaylist(special);
      repo.savePlaylist(regular);

      expect(repo.getIndestructiblePlaylists().map((p) => p.getName()), ['Special']);
      expect(repo.getNormalPlaylists().map((p) => p.getName()), ['Regular']);
    });
  });
}
