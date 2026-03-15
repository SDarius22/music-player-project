import 'dart:async';

import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';

class InMemorySongRepository implements SongRepository {
  final Map<int, Song> _byId = {};
  int _nextId = 1;

  final StreamController<List<Song>> _controller =
      StreamController<List<Song>>.broadcast();

  void _emit() {
    _controller.add(getAllSongs());
  }

  @override
  Stream watchSongs() {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (songs, sink) {
          sink.add(songs);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }

  @override
  Map<String, dynamic> get sortFields => const {
    'Title': null,
    'Duration': null,
    'Year': null,
  };

  @override
  Song saveSong(Song song) {
    if (song.id == 0) {
      song.id = _nextId++;
    }
    _byId[song.id] = song;
    _emit();
    return song;
  }

  @override
  List<Song> saveSongs(List<Song> songs) {
    for (final s in songs) {
      saveSong(s);
    }
    return songs;
  }

  @override
  int getSongCount() => _byId.length;

  @override
  Song getSongByPath(String path) {
    try {
      return _byId.values.firstWhere((s) => s.path == path);
    } catch (_) {
      throw Exception('Song with path $path not found');
    }
  }

  @override
  Song? getSongByServerId(int serverId) {
    for (final s in _byId.values) {
      if (s.serverId == serverId) return s;
    }
    return null;
  }

  @override
  Song getSong(int id) {
    final s = _byId[id];
    if (s == null) throw Exception('Song with id $id not found');
    return s;
  }

  @override
  Song getSongContaining(String query) {
    try {
      return _byId.values.firstWhere(
        (s) => s.path.toLowerCase().contains(query.toLowerCase()),
      );
    } catch (_) {
      throw Exception('Song containing $query not found');
    }
  }

  @override
  Song? getMostRecentPlayedSong() {
    final withLastPlayed =
        _byId.values.where((s) => s.lastPlayed != null).toList();
    if (withLastPlayed.isEmpty) return null;
    withLastPlayed.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return withLastPlayed.first;
  }

  @override
  List<Song> getRecentlyPlayedSongs(int limit) {
    final withLastPlayed =
        _byId.values.where((s) => s.lastPlayed != null).toList();
    withLastPlayed.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return withLastPlayed.take(limit).toList();
  }

  @override
  List<Song> getMostPlayedSongs(int limit) {
    final played = _byId.values.where((s) => s.playCount > 0).toList();
    played.sort((a, b) => b.playCount.compareTo(a.playCount));
    return played.take(limit).toList();
  }

  @override
  List<Song> getFavoriteSongs() {
    return _byId.values.where((s) => s.likedByUser == true).toList();
  }

  @override
  List<Song> getSongs(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final filtered =
        _byId.values.where((s) => s.name.toLowerCase().contains(q)).toList();

    int compare(Song a, Song b) {
      int res;
      switch (sortField) {
        case 'Duration':
          res = a.durationInSeconds.compareTo(b.durationInSeconds);
          break;
        case 'Year':
          res = a.year.compareTo(b.year);
          break;
        case 'Title':
        default:
          res = a.name.compareTo(b.name);
      }
      return ascending ? res : -res;
    }

    filtered.sort(compare);
    return filtered;
  }

  @override
  List<Song> getSongsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final all = getSongs(query, sortField, ascending);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  List<Song> getAllSongs() {
    final all = _byId.values.toList();
    all.sort((a, b) => a.name.compareTo(b.name));
    return all;
  }

  @override
  List<Song> getUnsyncedSongs() =>
      _byId.values.where((s) => s.requiresSync == true).toList();

  @override
  void markSongsAsSynced(List<int> serverIds) {
    for (final s in _byId.values) {
      if (serverIds.contains(s.serverId)) {
        s.requiresSync = false;
      }
    }
    _emit();
  }

  @override
  void deleteSong(Song song) {
    _byId.remove(song.id);
    _emit();
  }

  @override
  void updateSong(Song song) {
    _byId[song.id] = song;
    _emit();
  }

  @override
  void updateSongs(List<Song> songs) {
    for (final s in songs) {
      _byId[s.id] = s;
    }
    _emit();
  }
}
