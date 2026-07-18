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

  bool _isLocalSong(Song song) => song.isLocal;

  List<Song> _paginate(List<Song> songs, int offset, int limit) {
    if (offset >= songs.length) {
      return [];
    }
    final end = (offset + limit).clamp(0, songs.length);
    return songs.sublist(offset, end);
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
  int getSongCount(String query, bool localOnly) {
    final q = query.toLowerCase();
    return _byId.values
        .where(
          (s) =>
              s.getName().toLowerCase().contains(q) &&
              s.fullyLoaded &&
              (!localOnly || _isLocalSong(s)),
        )
        .length;
  }

  @override
  Song? getSongByFileHash(String fileHash) {
    if (fileHash.isEmpty) return null;
    for (final s in _byId.values) {
      if (s.getHash() == fileHash) return s;
    }
    return null;
  }

  @override
  Song? getSongByLocalPath(String path) {
    if (path.isEmpty) return null;
    for (final song in _byId.values) {
      if (song.path == path) return song;
    }
    return null;
  }

  @override
  Song getOrCreateSong(String fileHash) {
    final existing = getSongByFileHash(fileHash);
    if (existing != null) return existing;
    final newSong = Song(fileHash);
    return saveSong(newSong);
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

  List<Song> getSongs(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
  ) {
    // localOnly is ignored in this in-memory implementation, as this repo only works on web, where all songs are remote
    final q = query.toLowerCase();
    final filtered =
        _byId.values
            .where(
              (s) => s.getName().toLowerCase().contains(q) && s.fullyLoaded,
            )
            .toList();

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
          res = a.getName().compareTo(b.getName());
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
    bool localOnly,
    int offset,
    int limit,
  ) {
    final all = getSongs(query, sortField, ascending, localOnly);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  int getAlbumSongCount(String albumHash, bool localOnly) {
    return _byId.values.where((song) {
      if (!song.fullyLoaded) {
        return false;
      }
      if (song.album.target?.hash != albumHash) {
        return false;
      }
      if (localOnly && !_isLocalSong(song)) {
        return false;
      }
      return true;
    }).length;
  }

  @override
  List<Song> getAlbumSongsPaged(
    String albumHash,
    bool localOnly,
    int offset,
    int limit,
  ) {
    final songs =
        _byId.values.where((song) {
          if (!song.fullyLoaded) {
            return false;
          }
          if (song.album.target?.hash != albumHash) {
            return false;
          }
          if (localOnly && !_isLocalSong(song)) {
            return false;
          }
          return true;
        }).toList();

    songs.sort((a, b) {
      final discCompare = a.discNumber.compareTo(b.discNumber);
      if (discCompare != 0) {
        return discCompare;
      }
      final trackCompare = a.trackNumber.compareTo(b.trackNumber);
      if (trackCompare != 0) {
        return trackCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return _paginate(songs, offset, limit);
  }

  @override
  int getArtistSongCount(String artistHash, bool localOnly) {
    return _byId.values.where((song) {
      if (!song.fullyLoaded) {
        return false;
      }
      if (song.artist.target?.hash != artistHash) {
        return false;
      }
      if (localOnly && !_isLocalSong(song)) {
        return false;
      }
      return true;
    }).length;
  }

  @override
  List<Song> getArtistSongsPaged(
    String artistHash,
    bool localOnly,
    int offset,
    int limit,
  ) {
    final songs =
        _byId.values.where((song) {
          if (!song.fullyLoaded) {
            return false;
          }
          if (song.artist.target?.hash != artistHash) {
            return false;
          }
          if (localOnly && !_isLocalSong(song)) {
            return false;
          }
          return true;
        }).toList();

    songs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _paginate(songs, offset, limit);
  }

  @override
  int getPlaylistSongCount(List<String> songFileHashes, bool localOnly) {
    final hashSet = songFileHashes.toSet();
    return _byId.values.where((song) {
      if (!song.fullyLoaded) {
        return false;
      }
      if (!hashSet.contains(song.fileHash)) {
        return false;
      }
      if (localOnly && !_isLocalSong(song)) {
        return false;
      }
      return true;
    }).length;
  }

  @override
  List<Song> getPlaylistSongsPaged(
    List<String> songFileHashes,
    bool localOnly,
    int offset,
    int limit,
  ) {
    final orderByHash = <String, int>{};
    for (var i = 0; i < songFileHashes.length; i++) {
      orderByHash[songFileHashes[i]] = i;
    }

    final songs =
        _byId.values.where((song) {
          if (!song.fullyLoaded) {
            return false;
          }
          if (!orderByHash.containsKey(song.fileHash)) {
            return false;
          }
          if (localOnly && !_isLocalSong(song)) {
            return false;
          }
          return true;
        }).toList();

    songs.sort((a, b) {
      final aOrder = orderByHash[a.fileHash] ?? 1 << 30;
      final bOrder = orderByHash[b.fileHash] ?? 1 << 30;
      return aOrder.compareTo(bOrder);
    });

    return _paginate(songs, offset, limit);
  }

  @override
  List<Song> getAllSongs() {
    final all = _byId.values.toList();
    all.sort((a, b) => a.getName().compareTo(b.getName()));
    return all;
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
