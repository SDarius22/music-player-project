import 'dart:async';

import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';

class InMemoryPlaylistRepository implements PlaylistRepository {
  final Map<int, Playlist> _byId = {};
  int _nextId = 1;

  final StreamController<List<Playlist>> _controller =
      StreamController<List<Playlist>>.broadcast();

  void _emit() => _controller.add(getAllPlaylists());

  @override
  Stream watchPlaylists() {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (playlists, sink) {
          sink.add(playlists);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }

  @override
  Map<String, dynamic> get sortFields => const {
    'Name': null,
    'Created At': null,
  };

  @override
  Playlist savePlaylist(Playlist playlist) {
    if (playlist.id == 0) {
      playlist.id = _nextId++;
    }
    _byId[playlist.id] = playlist;
    _emit();
    return playlist;
  }

  @override
  Playlist? getPlaylistByName(String name) {
    for (final p in _byId.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  Playlist? getPlaylist(int id) => _byId[id];

  @override
  List<Playlist> getIndestructiblePlaylists() =>
      _byId.values.where((p) => p.indestructible == true).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  List<Playlist> getNormalPlaylists() =>
      _byId.values.where((p) => p.indestructible != true).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  List<Playlist> getAllPlaylists() {
    final list = _byId.values.toList();
    list.sort((a, b) {
      final ind = (b.indestructible ? 1 : 0) - (a.indestructible ? 1 : 0);
      if (ind != 0) return ind;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  List<Playlist> getPlaylists(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final list =
        _byId.values.where((p) => p.name.toLowerCase().contains(q)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!ascending) list.reversed;
    return list;
  }

  @override
  void deletePlaylist(Playlist playlist) {
    _byId.remove(playlist.id);
    _emit();
  }
}
