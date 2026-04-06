import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class InMemoryAlbumRepository implements AlbumRepository {
  final Map<int, Album> _byId = {};
  int _nextId = 1;

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  @override
  Album saveAlbum(Album album) {
    if (album.id == 0) {
      album.id = _nextId++;
    }
    _byId[album.id] = album;
    return album;
  }

  @override
  Album? getAlbumByHash(String hash) {
    for (final a in _byId.values) {
      if (a.getHash() == hash) return a;
    }
    return null;
  }

  @override
  Album getOrCreateAlbum(String albumHash, String albumName, Artist artist) {
    final existing = getAlbumByHash(albumHash);
    if (existing != null) return existing;
    var album = Album(albumHash, albumName, artist);
    return saveAlbum(album);
  }

  @override
  List<Album> getAlbums(String query, String sortField, bool ascending) {
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
  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final all = getAlbums(query, sortField, ascending);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  void updateAlbum(Album album) {
    _byId[album.id] = album;
  }
}
