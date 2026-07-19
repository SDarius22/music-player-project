import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';

void main() {
  group('InMemorySongRepository', () {
    test('getOrCreateSong reuses entity for the same hash', () {
      final repo = InMemorySongRepository();

      final first = repo.getOrCreateSong('song-hash');
      first.fullyLoaded = true;
      repo.saveSong(first);
      final second = repo.getOrCreateSong('song-hash');

      expect(first.id, isPositive);
      expect(second.id, first.id);
      expect(repo.getSongCount('', false), 1);
    });

    test('watchSongs emits an initial snapshot and then changes', () async {
      final repo = InMemorySongRepository();

      expect(await repo.watchSongs().first, isEmpty);
      final future = repo.watchSongs().skip(1).first;
      repo.saveSong(Song('new-song')..name = 'New Song');

      final emitted = await future as List<Song>;
      expect(emitted, hasLength(1));
      expect(emitted.first.getHash(), 'new-song');
    });

    test('favorite and most played queries return expected songs', () {
      final repo = InMemorySongRepository();
      final a =
          Song('a')
            ..likedByUser = true
            ..playCount = 1;
      final b = Song('b')..playCount = 5;
      repo.saveSongs([a, b]);

      expect(repo.getFavoriteSongs().map((s) => s.getHash()), ['a']);
      expect(repo.getMostPlayedSongs(1).single.getHash(), 'b');
    });

    test('sorts, searches, paginates, updates, and deletes songs', () {
      final repo = InMemorySongRepository();
      final a =
          Song('a')
            ..name = 'Alpha'
            ..fullyLoaded = true
            ..durationInSeconds = 30
            ..year = 2020;
      final b =
          Song('b')
            ..name = 'Beta'
            ..fullyLoaded = true
            ..durationInSeconds = 10
            ..year = 2024;
      repo.saveSongs([b, a]);

      expect(repo.getSongCount('a', false), 2);
      expect(repo.getSongs('', 'Title', true, false), [a, b]);
      expect(repo.getSongs('', 'Duration', true, false), [b, a]);
      expect(repo.getSongs('', 'Year', false, false), [b, a]);
      expect(repo.getSongsPaged('', 'Title', true, false, 1, 1), [b]);
      expect(repo.getSongsPaged('', 'Title', true, false, 4, 1), isEmpty);
      expect(repo.getAllSongs(), [a, b]);

      a.name = 'Updated';
      repo.updateSong(a);
      expect(repo.getSongByFileHash('a')!.name, 'Updated');
      b.name = 'Changed';
      repo.updateSongs([b]);
      expect(repo.getSongByFileHash('b')!.name, 'Changed');
      repo.deleteSong(a);
      expect(repo.getSongByFileHash('a'), isNull);
      expect(repo.getSongByFileHash(''), isNull);
    });

    test('queries recent, album, artist, and playlist songs', () {
      final repo = InMemorySongRepository();
      final album = Album('album', 'Album');
      final artist = Artist('artist', 'Artist');
      Song make(String hash, String name, int track, {bool local = false}) {
        final song =
            Song(hash)
              ..name = name
              ..fullyLoaded = true
              ..discNumber = 1
              ..trackNumber = track
              ..lastPlayed = DateTime.utc(2025, 1, track)
              ..path = local ? '/tmp/$hash.mp3' : null;
        song.album.target = album;
        song.artist.target = artist;
        return song;
      }

      final first = make('first', 'Zulu', 1, local: true);
      final second = make('second', 'Alpha', 2);
      final unloaded = Song('unloaded');
      repo.saveSongs([second, unloaded, first]);

      expect(repo.getMostRecentPlayedSong(), second);
      expect(repo.getRecentlyPlayedSongs(1), [second]);
      expect(repo.getAlbumSongCount('album', false), 2);
      expect(repo.getAlbumSongCount('album', true), 1);
      expect(repo.getAlbumSongsPaged('album', false, 0, 1), [first]);
      expect(repo.getAlbumSongsPaged('album', false, 9, 1), isEmpty);
      expect(repo.getArtistSongCount('artist', false), 2);
      expect(repo.getArtistSongCount('artist', true), 1);
      expect(repo.getArtistSongsPaged('artist', false, 0, 2), [second, first]);
      expect(repo.getPlaylistSongCount(['second', 'first'], false), 2);
      expect(repo.getPlaylistSongCount(['second', 'first'], true), 1);
      expect(repo.getPlaylistSongsPaged(['second', 'first'], false, 0, 2), [
        second,
        first,
      ]);
      expect(repo.getPlaylistSongsPaged(['first'], false, 3, 1), isEmpty);
    });

    test('recent lookup is null without playback history', () {
      final repo = InMemorySongRepository()..saveSong(Song('song'));
      expect(repo.getMostRecentPlayedSong(), isNull);
      expect(repo.getRecentlyPlayedSongs(5), isEmpty);
    });
  });
}
