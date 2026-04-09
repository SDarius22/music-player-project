import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';

void main() {
  group('InMemorySongRepository', () {
    test('getOrCreateSong reuses entity for the same hash', () {
      final repo = InMemorySongRepository();

      final first = repo.getOrCreateSong('song-hash');
      final second = repo.getOrCreateSong('song-hash');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getSongCount(), 1);
    });

    test('watchSongs emits after save', () async {
      final repo = InMemorySongRepository();

      final future = repo.watchSongs().first;
      repo.saveSong(Song('new-song')..setName('Hello'));

      final emitted = await future as List<Song>;
      expect(emitted, hasLength(1));
      expect(emitted.first.getHash(), 'new-song');
    });

    test('favorite and most played queries return expected songs', () {
      final repo = InMemorySongRepository();
      final a = Song('a')
        ..likedByUser = true
        ..playCount = 1;
      final b = Song('b')
        ..playCount = 5;
      repo.saveSongs([a, b]);

      expect(repo.getFavoriteSongs().map((s) => s.getHash()), ['a']);
      expect(repo.getMostPlayedSongs(1).single.getHash(), 'b');
    });
  });
}
