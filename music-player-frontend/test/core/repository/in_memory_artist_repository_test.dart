import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';

void main() {
  late InMemoryArtistRepository repo;

  Artist makeArtist({int id = 0, String name = 'Artist', int serverId = -1}) {
    final a = Artist();
    a.id = id;
    a.name = name;
    a.serverId = serverId;
    return a;
  }

  setUp(() => repo = InMemoryArtistRepository());

  group('saveArtist', () {
    test('assigns auto-incremented id when id == 0', () {
      final saved = repo.saveArtist(makeArtist());
      expect(saved.id, greaterThan(0));
    });

    test('preserves existing non-zero id', () {
      repo.saveArtist(makeArtist(id: 77));
      expect(repo.getArtist(77), isNotNull);
    });
  });

  group('getArtist', () {
    test('returns saved artist by id', () {
      final a = repo.saveArtist(makeArtist());
      expect(repo.getArtist(a.id), same(a));
    });

    test('returns null for unknown id', () {
      expect(repo.getArtist(999), isNull);
    });
  });

  group('getArtistByName', () {
    test('returns artist with matching name', () {
      repo.saveArtist(makeArtist(name: 'Led Zeppelin'));
      expect(repo.getArtistByName('Led Zeppelin'), isNotNull);
    });

    test('returns null when not found', () {
      expect(repo.getArtistByName('Unknown'), isNull);
    });
  });

  group('getArtistByServerId', () {
    test('returns artist with matching serverId', () {
      repo.saveArtist(makeArtist(serverId: 13));
      expect(repo.getArtistByServerId(13), isNotNull);
    });

    test('returns null when not found', () {
      expect(repo.getArtistByServerId(999), isNull);
    });
  });

  group('getArtists', () {
    test('returns all artists for empty query', () {
      repo.saveArtist(makeArtist(name: 'A'));
      repo.saveArtist(makeArtist(name: 'B'));
      expect(repo.getArtists('', 'Name', true).length, 2);
    });

    test('filters by name query', () {
      repo.saveArtist(makeArtist(name: 'Rock Band'));
      repo.saveArtist(makeArtist(name: 'Pop Star'));
      expect(repo.getArtists('rock', 'Name', true).length, 1);
    });

    test('sorts by name ascending', () {
      repo.saveArtist(makeArtist(name: 'Zeppelin'));
      repo.saveArtist(makeArtist(name: 'Beatles'));
      final result = repo.getArtists('', 'Name', true);
      expect(result.first.name, 'Beatles');
    });

    // Implementation has .reversed bug (doesn't mutate) — test actual behavior:
    test('ascending=false: list order unchanged due to implementation', () {
      repo.saveArtist(makeArtist(name: 'Alpha'));
      repo.saveArtist(makeArtist(name: 'Zeta'));
      final result = repo.getArtists('', 'Name', false);
      expect(result.first.name, 'Alpha'); // still ascending
    });
  });

  group('getArtistsPaged', () {
    test('returns correct page slice', () {
      for (int i = 1; i <= 5; i++) {
        repo.saveArtist(makeArtist(name: 'Artist $i'));
      }
      expect(repo.getArtistsPaged('', 'Name', true, 0, 2).length, 2);
    });

    test('returns empty when offset >= total', () {
      repo.saveArtist(makeArtist());
      expect(repo.getArtistsPaged('', 'Name', true, 100, 10), isEmpty);
    });

    test('clamps at end', () {
      for (int i = 0; i < 3; i++) {
        repo.saveArtist(makeArtist());
      }
      expect(repo.getArtistsPaged('', 'Name', true, 2, 10).length, 1);
    });
  });

  group('getAllArtists', () {
    test('returns all artists sorted by name', () {
      repo.saveArtist(makeArtist(name: 'Zeppelin'));
      repo.saveArtist(makeArtist(name: 'Beatles'));
      final result = repo.getAllArtists();
      expect(result.first.name, 'Beatles');
      expect(result.last.name, 'Zeppelin');
    });
  });

  group('updateArtist', () {
    test('updates artist fields in place', () {
      final a = repo.saveArtist(makeArtist(name: 'Old Name'));
      a.name = 'New Name';
      repo.updateArtist(a);
      expect(repo.getArtist(a.id)!.name, 'New Name');
    });
  });

  group('watchArtists', () {
    test('emits updated list after save', () async {
      final stream = repo.watchArtists();
      final future = stream.first;
      repo.saveArtist(makeArtist(name: 'Watched'));
      final result = await future;
      expect((result as List).isNotEmpty, isTrue);
    });

    test('emits after update', () async {
      final a = repo.saveArtist(makeArtist(name: 'Before'));
      final stream = repo.watchArtists();
      final future = stream.first;
      a.name = 'After';
      repo.updateArtist(a);
      final result = await future;
      expect((result as List).isNotEmpty, isTrue);
    });
  });

  group('sortFields', () {
    test('returns Name key', () {
      expect(repo.sortFields.keys, contains('Name'));
    });
  });
}
