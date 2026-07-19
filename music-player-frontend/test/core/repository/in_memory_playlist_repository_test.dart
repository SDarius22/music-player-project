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
      final queue = Playlist('Queue')..indestructible = true;
      final regular = Playlist('Regular');
      repo.savePlaylist(special);
      repo.savePlaylist(queue);
      repo.savePlaylist(regular);

      expect(repo.getIndestructiblePlaylists(0, 10).map((p) => p.getName()), [
        'Queue',
        'Special',
      ]);
      expect(repo.getNormalPlaylists(0, 10).map((p) => p.getName()), [
        'Queue',
        'Regular',
      ]);
      expect(repo.getIndestructiblePlaylistCount(), 2);
      expect(repo.getNormalPlaylistCount(), 2);
      expect(repo.getPlaylistCount('reg', false), 1);
      expect(repo.sortFields.keys, ['Name', 'Created At']);
      expect(repo.getIndestructiblePlaylists(5, 10), isEmpty);
      expect(repo.getNormalPlaylists(5, 10), isEmpty);
    });

    test('all, paged, and deletion operations retain stable ordering', () {
      final repo = InMemoryPlaylistRepository();
      final zebra = repo.savePlaylist(Playlist('Zebra'));
      repo.savePlaylist(Playlist('Alpha'));
      repo.savePlaylist(Playlist('Pinned')..indestructible = true);

      expect(repo.getAllPlaylists().map((p) => p.name), [
        'Pinned',
        'Alpha',
        'Zebra',
      ]);
      expect(
        repo.getPlaylistsPaged('', 'Name', true, false, 1, 1).single.name,
        'Alpha',
      );
      expect(repo.getPlaylistsPaged('', 'Name', true, false, 9, 1), isEmpty);
      repo.deletePlaylist(zebra);
      expect(repo.getPlaylistByName('Zebra'), isNull);
    });
  });
}
