import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';

class InMemoryArtistRepository implements ArtistRepository {
  final Map<int, Artist> _byId = {};
  int _nextId = 1;

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  @override
  Artist saveArtist(Artist artist) {
    if (artist.id == 0) {
      artist.id = _nextId++;
    } else if (artist.id >= _nextId) {
      _nextId = artist.id + 1;
    }
    _byId[artist.id] = artist;
    return artist;
  }

  @override
  Artist? getArtistByHash(String artistHash) {
    for (final a in _byId.values) {
      if (a.getHash() == artistHash) return a;
    }
    return null;
  }

  @override
  Artist getOrCreateArtist(String artistHash, String name) {
    final existing = getArtistByHash(artistHash);
    if (existing != null) return existing;
    var artist = Artist(artistHash, name);
    return saveArtist(artist);
  }

  @override
  int getArtistCount(String query, bool containLocalOnly) {
    final q = query.toLowerCase();
    return _byId.values
        .where(
          (artist) =>
              artist.getName().toLowerCase().contains(q) &&
              (!containLocalOnly || artist.isLocal),
        )
        .length;
  }

  List<Artist> getArtists(
    String query,
    String sortField,
    bool ascending, {
    bool localOnly = false,
  }) {
    final q = query.toLowerCase();
    final list =
        _byId.values
            .where(
              (artist) =>
                  artist.getName().toLowerCase().contains(q) &&
                  (!localOnly || artist.isLocal),
            )
            .toList();
    list.sort((a, b) {
      final result = a.getName().compareTo(b.getName());
      return ascending ? result : -result;
    });
    return list;
  }

  @override
  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  ) {
    final all = getArtists(
      query,
      sortField,
      ascending,
      localOnly: containLocalOnly,
    );
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  void updateArtist(Artist artist) {
    saveArtist(artist);
  }
}
