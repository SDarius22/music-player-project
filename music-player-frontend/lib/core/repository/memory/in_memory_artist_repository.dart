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
  List<Artist> getArtists(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final list =
        _byId.values
            .where((a) => a.getName().toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => a.getName().compareTo(b.getName()));
    if (!ascending) list.reversed;
    return list;
  }

  @override
  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final all = getArtists(query, sortField, ascending);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  void updateArtist(Artist artist) {
    _byId[artist.id] = artist;
  }
}
