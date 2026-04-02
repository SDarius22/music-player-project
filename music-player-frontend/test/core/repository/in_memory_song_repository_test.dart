import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';

void main() {
  late InMemorySongRepository repo;

  Song makeSong({
    int id = 0,
    String name = 'Test',
    String path = '',
    int serverId = -1,
    int playCount = 0,
    bool liked = false,
  }) {
    final s = Song();
    s.id = id;
    s.name = name;
    s.path = path;
    s.serverId = serverId;
    s.playCount = playCount;
    s.likedByUser = liked;
    return s;
  }

  setUp(() => repo = InMemorySongRepository());

  // ─── saveSong ────────────────────────────────────────────────────────────

  group('saveSong', () {
    test('assigns auto-incremented id when id == 0', () {
      final s = makeSong();
      final saved = repo.saveSong(s);
      expect(saved.id, greaterThan(0));
    });

    test('preserves existing non-zero id', () {
      final s = makeSong(id: 99);
      repo.saveSong(s);
      expect(repo.getSong(99), same(s));
    });

    test('auto-ids increment for each new song', () {
      final a = repo.saveSong(makeSong());
      final b = repo.saveSong(makeSong());
      expect(b.id, greaterThan(a.id));
    });
  });

  // ─── saveSongs ───────────────────────────────────────────────────────────

  group('saveSongs', () {
    test('saves multiple songs and returns them', () {
      final songs = [makeSong(name: 'A'), makeSong(name: 'B')];
      final result = repo.saveSongs(songs);
      expect(repo.getSongCount(), 2);
      expect(result, equals(songs));
    });
  });

  // ─── getSongCount ────────────────────────────────────────────────────────

  group('getSongCount', () {
    test('returns 0 initially', () => expect(repo.getSongCount(), 0));

    test('increments after each save', () {
      repo.saveSong(makeSong());
      repo.saveSong(makeSong());
      expect(repo.getSongCount(), 2);
    });
  });

  // ─── getSong ─────────────────────────────────────────────────────────────

  group('getSong', () {
    test('returns saved song by id', () {
      final s = repo.saveSong(makeSong());
      expect(repo.getSong(s.id), same(s));
    });

    test('throws when id not found', () {
      expect(() => repo.getSong(999), throwsException);
    });
  });

  // ─── getSongByPath ───────────────────────────────────────────────────────

  group('getSongByPath', () {
    test('returns song with matching path', () {
      final s = makeSong(path: '/music/track.mp3');
      repo.saveSong(s);
      expect(repo.getSongByPath('/music/track.mp3'), same(s));
    });

    test('throws when path not found', () {
      expect(() => repo.getSongByPath('/not/found.mp3'), throwsException);
    });
  });

  // ─── getSongByServerId ───────────────────────────────────────────────────

  group('getSongByServerId', () {
    test('returns song with matching serverId', () {
      final s = makeSong(serverId: 42);
      repo.saveSong(s);
      expect(repo.getSongByServerId(42), same(s));
    });

    test('returns null when not found', () {
      expect(repo.getSongByServerId(999), isNull);
    });
  });

  // ─── getSongContaining ───────────────────────────────────────────────────

  group('getSongContaining', () {
    test('matches song whose PATH contains query', () {
      final s = makeSong(path: '/music/rock/beat.mp3');
      repo.saveSong(s);
      expect(repo.getSongContaining('rock'), same(s));
    });

    test('is case-insensitive', () {
      final s = makeSong(path: '/MUSIC/ROCK.mp3');
      repo.saveSong(s);
      expect(repo.getSongContaining('music'), same(s));
    });

    test('returns null when no path matches', () {
      repo.saveSong(makeSong(path: '/pop/song.mp3'));
      expect(repo.getSongContaining('jazz'), isNull);
    });
  });

  // ─── getMostRecentPlayedSong ─────────────────────────────────────────────

  group('getMostRecentPlayedSong', () {
    test('returns null when repository is empty', () {
      expect(repo.getMostRecentPlayedSong(), isNull);
    });

    test('returns null when no songs have lastPlayed set', () {
      repo.saveSong(makeSong());
      expect(repo.getMostRecentPlayedSong(), isNull);
    });

    test('returns song with most recent lastPlayed', () {
      final old = makeSong(name: 'Old');
      old.lastPlayed = DateTime(2024, 1, 1);
      final recent = makeSong(name: 'Recent');
      recent.lastPlayed = DateTime(2024, 6, 1);
      repo.saveSong(old);
      repo.saveSong(recent);
      expect(repo.getMostRecentPlayedSong()?.name, 'Recent');
    });
  });

  // ─── getRecentlyPlayedSongs ──────────────────────────────────────────────

  group('getRecentlyPlayedSongs', () {
    test('returns songs sorted descending by lastPlayed', () {
      for (int i = 1; i <= 5; i++) {
        final s = makeSong(name: 'Song $i');
        s.lastPlayed = DateTime(2024, i, 1);
        repo.saveSong(s);
      }
      final result = repo.getRecentlyPlayedSongs(5);
      expect(result.first.name, 'Song 5');
    });

    test('limits result to requested count', () {
      for (int i = 1; i <= 5; i++) {
        final s = makeSong(name: 'Song $i');
        s.lastPlayed = DateTime(2024, i, 1);
        repo.saveSong(s);
      }
      expect(repo.getRecentlyPlayedSongs(3).length, 3);
    });

    test('excludes songs with no lastPlayed', () {
      repo.saveSong(makeSong(name: 'Never Played'));
      expect(repo.getRecentlyPlayedSongs(10), isEmpty);
    });
  });

  // ─── getMostPlayedSongs ──────────────────────────────────────────────────

  group('getMostPlayedSongs', () {
    test('returns songs sorted by playCount descending', () {
      repo.saveSong(makeSong(name: 'Rare', playCount: 1));
      repo.saveSong(makeSong(name: 'Popular', playCount: 50));
      expect(repo.getMostPlayedSongs(2).first.name, 'Popular');
    });

    test('limits result', () {
      for (int i = 1; i <= 5; i++) {
        repo.saveSong(makeSong(name: 'S$i', playCount: i));
      }
      expect(repo.getMostPlayedSongs(2).length, 2);
    });

    test('excludes songs with 0 play count', () {
      repo.saveSong(makeSong(name: 'Unplayed', playCount: 0));
      expect(repo.getMostPlayedSongs(10), isEmpty);
    });
  });

  // ─── getFavoriteSongs ────────────────────────────────────────────────────

  group('getFavoriteSongs', () {
    test('returns only songs with likedByUser == true', () {
      repo.saveSong(makeSong(name: 'Liked', liked: true));
      repo.saveSong(makeSong(name: 'Nope'));
      final result = repo.getFavoriteSongs();
      expect(result.length, 1);
      expect(result.first.name, 'Liked');
    });

    test('returns empty list when none liked', () {
      repo.saveSong(makeSong());
      expect(repo.getFavoriteSongs(), isEmpty);
    });
  });

  // ─── getSongs ────────────────────────────────────────────────────────────

  group('getSongs', () {
    test('empty query returns all songs', () {
      repo.saveSong(makeSong(name: 'A'));
      repo.saveSong(makeSong(name: 'B'));
      expect(repo.getSongs('', 'Title', true).length, 2);
    });

    test('filters by name query (case-insensitive)', () {
      repo.saveSong(makeSong(name: 'Rock Song'));
      repo.saveSong(makeSong(name: 'Pop Song'));
      expect(repo.getSongs('rock', 'Title', true).length, 1);
    });

    test('sorts by Title ascending', () {
      repo.saveSong(makeSong(name: 'Zeta'));
      repo.saveSong(makeSong(name: 'Alpha'));
      final result = repo.getSongs('', 'Title', true);
      expect(result.first.name, 'Alpha');
    });

    test('sorts by Title descending', () {
      repo.saveSong(makeSong(name: 'Alpha'));
      repo.saveSong(makeSong(name: 'Zeta'));
      final result = repo.getSongs('', 'Title', false);
      expect(result.first.name, 'Zeta');
    });

    test('sorts by Duration ascending', () {
      final short = makeSong(name: 'Short');
      short.durationInSeconds = 60;
      final long = makeSong(name: 'Long');
      long.durationInSeconds = 300;
      repo.saveSong(long);
      repo.saveSong(short);
      expect(repo.getSongs('', 'Duration', true).first.name, 'Short');
    });

    test('sorts by Duration descending', () {
      final short = makeSong(name: 'Short');
      short.durationInSeconds = 60;
      final long = makeSong(name: 'Long');
      long.durationInSeconds = 300;
      repo.saveSong(short);
      repo.saveSong(long);
      expect(repo.getSongs('', 'Duration', false).first.name, 'Long');
    });

    test('sorts by Year ascending', () {
      final old = makeSong(name: 'Old');
      old.year = 1990;
      final fresh = makeSong(name: 'New');
      fresh.year = 2020;
      repo.saveSong(fresh);
      repo.saveSong(old);
      expect(repo.getSongs('', 'Year', true).first.name, 'Old');
    });

    test('unknown sortField falls back to name sort', () {
      repo.saveSong(makeSong(name: 'B'));
      repo.saveSong(makeSong(name: 'A'));
      final result = repo.getSongs('', 'Unknown', true);
      expect(result.first.name, 'A');
    });
  });

  // ─── getSongsPaged ───────────────────────────────────────────────────────

  group('getSongsPaged', () {
    test('returns correct page slice', () {
      for (int i = 1; i <= 10; i++) {
        repo.saveSong(makeSong(name: 'Song ${i.toString().padLeft(2, '0')}'));
      }
      final page = repo.getSongsPaged('', 'Title', true, 0, 3);
      expect(page.length, 3);
    });

    test('returns empty list when offset >= total', () {
      repo.saveSong(makeSong());
      expect(repo.getSongsPaged('', 'Title', true, 100, 10), isEmpty);
    });

    test('clamps at end of list', () {
      for (int i = 0; i < 5; i++) {
        repo.saveSong(makeSong());
      }
      final page = repo.getSongsPaged('', 'Title', true, 3, 10);
      expect(page.length, 2);
    });
  });

  // ─── getAllSongs ─────────────────────────────────────────────────────────

  group('getAllSongs', () {
    test('returns all songs sorted by name', () {
      repo.saveSong(makeSong(name: 'Zeta'));
      repo.saveSong(makeSong(name: 'Alpha'));
      final result = repo.getAllSongs();
      expect(result.first.name, 'Alpha');
      expect(result.last.name, 'Zeta');
    });
  });

  // ─── getUnsyncedSongs ────────────────────────────────────────────────────

  group('getUnsyncedSongs', () {
    test('returns only songs with requiresSync == true', () {
      final synced = makeSong(name: 'Synced');
      synced.requiresSync = false;
      final unsynced = makeSong(name: 'Unsynced');
      unsynced.requiresSync = true;
      repo.saveSong(synced);
      repo.saveSong(unsynced);
      final result = repo.getUnsyncedSongs();
      expect(result.length, 1);
      expect(result.first.name, 'Unsynced');
    });
  });

  // ─── markSongsAsSynced ───────────────────────────────────────────────────

  group('markSongsAsSynced', () {
    test('clears requiresSync for matching serverIds', () {
      final s = makeSong(serverId: 5);
      s.requiresSync = true;
      repo.saveSong(s);
      repo.markSongsAsSynced([5]);
      expect(s.requiresSync, isFalse);
    });

    test('does not affect songs with different serverIds', () {
      final s = makeSong(serverId: 10);
      s.requiresSync = true;
      repo.saveSong(s);
      repo.markSongsAsSynced([99]);
      expect(s.requiresSync, isTrue);
    });
  });

  // ─── deleteSong ──────────────────────────────────────────────────────────

  group('deleteSong', () {
    test('removes song from repository', () {
      final s = repo.saveSong(makeSong());
      repo.deleteSong(s);
      expect(repo.getSongCount(), 0);
    });
  });

  // ─── updateSong ──────────────────────────────────────────────────────────

  group('updateSong', () {
    test('updates song fields in place', () {
      final s = repo.saveSong(makeSong(name: 'Original'));
      s.name = 'Updated';
      repo.updateSong(s);
      expect(repo.getSong(s.id).name, 'Updated');
    });
  });

  // ─── updateSongs ─────────────────────────────────────────────────────────

  group('updateSongs', () {
    test('updates multiple songs', () {
      final s1 = repo.saveSong(makeSong(name: 'A'));
      final s2 = repo.saveSong(makeSong(name: 'B'));
      s1.name = 'A2';
      s2.name = 'B2';
      repo.updateSongs([s1, s2]);
      expect(repo.getSong(s1.id).name, 'A2');
      expect(repo.getSong(s2.id).name, 'B2');
    });
  });

  // ─── watchSongs ──────────────────────────────────────────────────────────

  group('watchSongs', () {
    test('emits updated list after save', () async {
      final stream = repo.watchSongs();
      final future = stream.first;
      repo.saveSong(makeSong(name: 'Watched'));
      final result = await future;
      expect((result as List).isNotEmpty, isTrue);
    });

    test('emits after delete', () async {
      final s = repo.saveSong(makeSong());
      final stream = repo.watchSongs();
      final future = stream.first;
      repo.deleteSong(s);
      final result = await future;
      expect((result as List), isEmpty);
    });
  });

  // ─── sortFields ──────────────────────────────────────────────────────────

  group('sortFields', () {
    test('returns expected keys', () {
      expect(repo.sortFields.keys, containsAll(['Title', 'Duration', 'Year']));
    });
  });
}
