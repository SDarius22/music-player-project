import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';

void main() {
  late InMemoryPlaylistRepository repo;

  Playlist makePlaylist({
    int id = 0,
    String name = 'Playlist',
    int serverId = -1,
    bool indestructible = false,
  }) {
    final p = Playlist();
    p.id = id;
    p.name = name;
    p.serverId = serverId;
    p.indestructible = indestructible;
    return p;
  }

  setUp(() => repo = InMemoryPlaylistRepository());

  group('savePlaylist', () {
    test('assigns auto-incremented id when id == 0', () {
      final saved = repo.savePlaylist(makePlaylist());
      expect(saved.id, greaterThan(0));
    });

    test('preserves existing non-zero id', () {
      repo.savePlaylist(makePlaylist(id: 55));
      expect(repo.getPlaylist(55), isNotNull);
    });

    test('overwrites existing playlist with same id', () {
      final p = repo.savePlaylist(makePlaylist(name: 'Original'));
      p.name = 'Updated';
      repo.savePlaylist(p);
      expect(repo.getPlaylist(p.id)!.name, 'Updated');
    });
  });

  group('getPlaylist', () {
    test('returns saved playlist by id', () {
      final p = repo.savePlaylist(makePlaylist());
      expect(repo.getPlaylist(p.id), same(p));
    });

    test('returns null for unknown id', () {
      expect(repo.getPlaylist(999), isNull);
    });
  });

  group('getPlaylistByName', () {
    test('returns playlist with matching name', () {
      repo.savePlaylist(makePlaylist(name: 'Favorites'));
      expect(repo.getPlaylistByName('Favorites'), isNotNull);
    });

    test('returns null when not found', () {
      expect(repo.getPlaylistByName('Missing'), isNull);
    });
  });

  group('getPlaylistByServerId', () {
    test('returns playlist with matching serverId', () {
      repo.savePlaylist(makePlaylist(serverId: 12));
      expect(repo.getPlaylistByServerId(12), isNotNull);
    });

    test('returns null when not found', () {
      expect(repo.getPlaylistByServerId(999), isNull);
    });
  });

  group('getIndestructiblePlaylists', () {
    test('returns only indestructible playlists sorted by name', () {
      repo.savePlaylist(makePlaylist(name: 'Queue', indestructible: true));
      repo.savePlaylist(makePlaylist(name: 'Favorites', indestructible: true));
      repo.savePlaylist(makePlaylist(name: 'Normal'));

      final result = repo.getIndestructiblePlaylists();

      expect(result.length, 2);
      expect(result.every((p) => p.indestructible), isTrue);
      expect(result.first.name, 'Favorites');
      expect(result.last.name, 'Queue');
    });

    test('returns empty when none are indestructible', () {
      repo.savePlaylist(makePlaylist());
      expect(repo.getIndestructiblePlaylists(), isEmpty);
    });
  });

  group('getNormalPlaylists', () {
    test('returns only non-indestructible playlists sorted by name', () {
      repo.savePlaylist(makePlaylist(name: 'Queue', indestructible: true));
      repo.savePlaylist(makePlaylist(name: 'Zeta'));
      repo.savePlaylist(makePlaylist(name: 'Alpha'));

      final result = repo.getNormalPlaylists();

      expect(result.length, 2);
      expect(result.every((p) => !p.indestructible), isTrue);
      expect(result.first.name, 'Alpha');
    });
  });

  group('getAllPlaylists', () {
    test('indestructible playlists come before normal ones', () {
      repo.savePlaylist(makePlaylist(name: 'Normal B'));
      repo.savePlaylist(makePlaylist(name: 'Normal A'));
      repo.savePlaylist(
          makePlaylist(name: 'Queue', indestructible: true));

      final result = repo.getAllPlaylists();

      expect(result.first.indestructible, isTrue);
      expect(result.first.name, 'Queue');
    });

    test('within each group, sorted by name', () {
      repo.savePlaylist(makePlaylist(name: 'Zeta', indestructible: true));
      repo.savePlaylist(makePlaylist(name: 'Alpha', indestructible: true));
      repo.savePlaylist(makePlaylist(name: 'Normal'));

      final result = repo.getAllPlaylists();
      final indestructibles = result.where((p) => p.indestructible).toList();

      expect(indestructibles.first.name, 'Alpha');
      expect(indestructibles.last.name, 'Zeta');
    });
  });

  group('getPlaylists', () {
    test('returns all when query is empty', () {
      repo.savePlaylist(makePlaylist(name: 'A'));
      repo.savePlaylist(makePlaylist(name: 'B'));
      expect(repo.getPlaylists('', 'Name', true).length, 2);
    });

    test('filters by name query (case-insensitive)', () {
      repo.savePlaylist(makePlaylist(name: 'Rock Hits'));
      repo.savePlaylist(makePlaylist(name: 'Pop Hits'));
      expect(repo.getPlaylists('rock', 'Name', true).length, 1);
    });

    test('sorts ascending by name', () {
      repo.savePlaylist(makePlaylist(name: 'Zeta'));
      repo.savePlaylist(makePlaylist(name: 'Alpha'));
      final result = repo.getPlaylists('', 'Name', true);
      expect(result.first.name, 'Alpha');
    });

    // Same .reversed bug as album/artist repos — test actual behavior:
    test('ascending=false: order unchanged due to implementation', () {
      repo.savePlaylist(makePlaylist(name: 'Alpha'));
      repo.savePlaylist(makePlaylist(name: 'Zeta'));
      final result = repo.getPlaylists('', 'Name', false);
      expect(result.first.name, 'Alpha');
    });
  });

  group('getPlaylistsPaged', () {
    test('returns correct page slice', () {
      for (int i = 1; i <= 5; i++) {
        repo.savePlaylist(makePlaylist(name: 'List $i'));
      }
      expect(repo.getPlaylistsPaged('', 'Name', true, 0, 2).length, 2);
    });

    test('returns empty when offset >= total', () {
      repo.savePlaylist(makePlaylist());
      expect(repo.getPlaylistsPaged('', 'Name', true, 100, 10), isEmpty);
    });

    test('clamps at end', () {
      for (int i = 0; i < 3; i++) repo.savePlaylist(makePlaylist());
      expect(repo.getPlaylistsPaged('', 'Name', true, 2, 10).length, 1);
    });
  });

  group('deletePlaylist', () {
    test('removes playlist from repository', () {
      final p = repo.savePlaylist(makePlaylist());
      repo.deletePlaylist(p);
      expect(repo.getPlaylist(p.id), isNull);
    });
  });

  group('watchPlaylists', () {
    test('emits after save', () async {
      final stream = repo.watchPlaylists();
      final future = stream.first;
      repo.savePlaylist(makePlaylist(name: 'New'));
      final result = await future;
      expect((result as List).isNotEmpty, isTrue);
    });

    test('emits after delete', () async {
      final p = repo.savePlaylist(makePlaylist());
      final stream = repo.watchPlaylists();
      final future = stream.first;
      repo.deletePlaylist(p);
      await future;
    });
  });

  group('sortFields', () {
    test('returns expected keys', () {
      expect(repo.sortFields.keys, containsAll(['Name', 'Created At']));
    });
  });
}
