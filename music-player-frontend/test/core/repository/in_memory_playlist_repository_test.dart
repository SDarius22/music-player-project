import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';

void main() {
  group('InMemoryPlaylistRepository', () {
    test('getOrCreatePlaylist reuses playlist for same name', () {
      final repo = InMemoryPlaylistRepository();

      final first = repo.getOrCreatePlaylist('Favorites');
      final second = repo.getOrCreatePlaylist('Favorites');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getPlaylistByName('Favorites'), same(first));
    });

    test('indestructible and normal playlist filters work', () {
      final repo = InMemoryPlaylistRepository();
      final special = Playlist('Special')..indestructible = true;
      final regular = Playlist('Regular');
      repo.savePlaylist(special);
      repo.savePlaylist(regular);

      expect(repo.getIndestructiblePlaylists(0, 10).map((p) => p.getName()), [
        'Special',
      ]);
      expect(repo.getNormalPlaylists(0, 10).map((p) => p.getName()), [
        'Regular',
      ]);
    });
  });
}
