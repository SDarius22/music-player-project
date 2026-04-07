import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';

void main() {
  group('InMemoryArtistRepository', () {
    test('save/get by hash and getOrCreate reuse existing artist', () {
      final repo = InMemoryArtistRepository();

      final first = repo.getOrCreateArtist('artist-hash', 'Artist');
      final second = repo.getOrCreateArtist('artist-hash', 'Artist');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getArtistByHash('artist-hash')?.getName(), 'Artist');
    });

    test('paged query respects offset and limit', () {
      final repo = InMemoryArtistRepository();

      repo.getOrCreateArtist('hash-a', 'Alpha');
      repo.getOrCreateArtist('hash-b', 'Beta');
      repo.getOrCreateArtist('hash-c', 'Gamma');

      final page = repo.getArtistsPaged('', 'Name', true, 1, 1);

      expect(page, hasLength(1));
      expect(page.first.getName(), 'Beta');
    });
  });
}
