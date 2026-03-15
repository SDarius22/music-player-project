import 'dart:async';

import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class InMemoryAlbumRepository implements AlbumRepository {
  final Map<int, Album> _byId = {};
  int _nextId = 1;

  final StreamController<List<Album>> _controller =
      StreamController<List<Album>>.broadcast();

  void _emit() => _controller.add(getAllAlbums());

  @override
  Stream watchAlbums() {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (albums, sink) {
          sink.add(albums);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  @override
  Album saveAlbum(Album album) {
    if (album.id == 0) {
      album.id = _nextId++;
    }
    _byId[album.id] = album;
    _emit();
    return album;
  }

  @override
  Album? getAlbum(int albumId) => _byId[albumId];

  @override
  Album? getAlbumByName(String albumName) {
    for (final a in _byId.values) {
      if (a.name == albumName) return a;
    }
    return null;
  }

  @override
  List<Album> getAlbums(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final list =
        _byId.values.where((a) => a.name.toLowerCase().contains(q)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
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
  List<Album> getAllAlbums() {
    final list = _byId.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  void updateAlbum(Album album) {
    _byId[album.id] = album;
    _emit();
  }
}
