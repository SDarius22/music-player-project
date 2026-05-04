import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';

class InMemoryPlaylistRepository implements PlaylistRepository {
  final Map<int, Playlist> _byId = {};
  int _nextId = 1;

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
    return playlist;
  }

  @override
  Playlist? getPlaylistByName(String name) {
    for (final p in _byId.values) {
      if (p.getName() == name) return p;
    }
    return null;
  }

  @override
  Playlist getOrCreatePlaylist(String name) {
    Playlist? existingPlaylist = getPlaylistByName(name);
    if (existingPlaylist != null) {
      return existingPlaylist;
    }
    Playlist newPlaylist = Playlist(name);
    return savePlaylist(newPlaylist);
  }

  @override
  int getPlaylistCount(String query, bool containLocalOnly) {
    final q = query.toLowerCase();
    return _byId.values
        .where((p) => p.getName().toLowerCase().contains(q))
        .length;
  }

  @override
  List<Playlist> getIndestructiblePlaylists(int offset, int limit) {
    final all =
        _byId.values.where((p) => p.indestructible == true).toList()
          ..sort((a, b) => a.getName().compareTo(b.getName()));
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  int getIndestructiblePlaylistCount() {
    return _byId.values.where((p) => p.indestructible == true).length;
  }

  @override
  List<Playlist> getNormalPlaylists(int offset, int limit) {
    final all =
        _byId.values.where((p) => p.indestructible != true).toList()
          ..sort((a, b) => a.getName().compareTo(b.getName()));
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  int getNormalPlaylistCount() {
    return _byId.values.where((p) => p.indestructible != true).length;
  }

  @override
  List<Playlist> getAllPlaylists() {
    final list = _byId.values.toList();
    list.sort((a, b) {
      final ind = (b.indestructible ? 1 : 0) - (a.indestructible ? 1 : 0);
      if (ind != 0) return ind;
      return a.getName().compareTo(b.getName());
    });
    return list;
  }

  List<Playlist> getPlaylists(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final list =
        _byId.values
            .where((p) => p.getName().toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => a.getName().compareTo(b.getName()));
    if (!ascending) list.reversed;
    return list;
  }

  @override
  List<Playlist> getPlaylistsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  ) {
    final all = getPlaylists(query, sortField, ascending);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  void deletePlaylist(Playlist playlist) {
    _byId.remove(playlist.id);
  }
}
