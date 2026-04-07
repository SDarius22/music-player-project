import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';

void main() {
  group('InMemoryAlbumRepository', () {
    test('save/get by hash and getOrCreate reuse existing album', () {
      final repo = InMemoryAlbumRepository();
      final artist = Artist('artist-hash', 'Artist');

      final first = repo.getOrCreateAlbum('album-hash', 'Album', artist);
      final second = repo.getOrCreateAlbum('album-hash', 'Album', artist);

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getAlbumByHash('album-hash')?.getName(), 'Album');
    });

    test('paged query respects offset and limit', () {
      final repo = InMemoryAlbumRepository();
      final artist = Artist('artist-hash', 'Artist');

      repo.getOrCreateAlbum('hash-a', 'Alpha', artist);
      repo.getOrCreateAlbum('hash-b', 'Beta', artist);
      repo.getOrCreateAlbum('hash-c', 'Gamma', artist);

      final page = repo.getAlbumsPaged('', 'Name', true, 1, 1);

      expect(page, hasLength(1));
      expect(page.first.getName(), 'Beta');
    });
  });
}
