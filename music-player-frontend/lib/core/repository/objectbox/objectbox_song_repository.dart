import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';

class ObjectBoxSongRepository implements SongRepository {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

  bool _isLocalSong(Song song) => song.isLocal;

  List<Song> _paginate(List<Song> songs, int offset, int limit) {
    if (offset >= songs.length) {
      return [];
    }
    final end = (offset + limit).clamp(0, songs.length);
    return songs.sublist(offset, end);
  }

  @override
  Stream watchSongs() => _songBox
      .query()
      .watch(triggerImmediately: true)
      .map((query) => query.find());

  @override
  Map<String, dynamic> get sortFields => {
    'Title': Song_.name,
    'Duration': Song_.durationInSeconds,
    'Year': Song_.year,
  };

  @override
  Song saveSong(Song song) {
    song.id = _songBox.put(song);
    return song;
  }

  @override
  List<Song> saveSongs(List<Song> songs) {
    final ids = _songBox.putMany(songs);
    for (int i = 0; i < songs.length; i++) {
      songs[i].id = ids[i];
    }
    return songs;
  }

  @override
  int getSongCount(String query, bool localOnly) {
    var conditions = Song_.name
        .contains(query, caseSensitive: false)
        .and(Song_.fullyLoaded.equals(true));
    if (localOnly) {
      conditions = conditions.and(
        (Song_.path.notNull() & Song_.path.notEquals('')) |
            Song_.fullyCached.equals(true),
      );
    }
    return _songBox.query(conditions).build().count();
  }

  @override
  Song? getSongByFileHash(String fileHash) {
    if (fileHash.isEmpty) return null;
    return _songBox.query(Song_.fileHash.equals(fileHash)).build().findFirst();
  }

  @override
  Song? getSongByLocalPath(String path) {
    if (path.isEmpty) return null;
    return _songBox.query(Song_.path.equals(path)).build().findFirst();
  }

  @override
  Song getOrCreateSong(String fileHash) {
    final existing = getSongByFileHash(fileHash);
    if (existing != null) return existing;
    Song song = Song(fileHash);
    return saveSong(song);
  }

  @override
  Song? getMostRecentPlayedSong() {
    return _songBox
        .query(Song_.lastPlayed.notNull())
        .order(Song_.lastPlayed, flags: Order.descending)
        .build()
        .findFirst();
  }

  @override
  List<Song> getRecentlyPlayedSongs(int limit) {
    final query =
        _songBox
            .query(Song_.lastPlayed.notNull())
            .order(Song_.lastPlayed, flags: Order.descending)
            .build();

    query.limit = limit;

    return query.find();
  }

  @override
  List<Song> getMostPlayedSongs(int limit) {
    final query =
        _songBox
            .query(Song_.playCount.greaterThan(0))
            .order(Song_.playCount, flags: Order.descending)
            .build();

    query.limit = limit;

    return query.find();
  }

  @override
  List<Song> getFavoriteSongs() {
    return _songBox.query(Song_.likedByUser.equals(true)).build().find();
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
    var conditions = Song_.name
        .contains(query, caseSensitive: false)
        .and(Song_.fullyLoaded.equals(true));
    if (localOnly) {
      conditions = conditions.and(
        (Song_.path.notNull() & Song_.path.notEquals('')) |
            Song_.fullyCached.equals(true),
      );
    }
    final q =
        _songBox
            .query(conditions)
            .order(
              sortFields.containsKey(sortField)
                  ? sortFields[sortField]
                  : Song_.name,
              flags: ascending ? 0 : Order.descending,
            )
            .build();
    q.offset = offset;
    q.limit = limit;
    return q.find();
  }

  @override
  int getAlbumSongCount(String albumHash, bool localOnly) {
    return getAlbumSongsPaged(albumHash, localOnly, 0, 1 << 30).length;
  }

  @override
  List<Song> getAlbumSongsPaged(
    String albumHash,
    bool localOnly,
    int offset,
    int limit,
  ) {
    final songs =
        _songBox.getAll().where((song) {
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
    return getArtistSongsPaged(artistHash, localOnly, 0, 1 << 30).length;
  }

  @override
  List<Song> getArtistSongsPaged(
    String artistHash,
    bool localOnly,
    int offset,
    int limit,
  ) {
    final songs =
        _songBox.getAll().where((song) {
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
    return getPlaylistSongsPaged(songFileHashes, localOnly, 0, 1 << 30).length;
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
        _songBox.getAll().where((song) {
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
    return _songBox.query().order(Song_.name).build().find();
  }

  @override
  void deleteSong(Song song) {
    _songBox.remove(song.id);
  }

  @override
  void updateSong(Song song) {
    _songBox.put(song);
  }

  @override
  void updateSongs(List<Song> songs) {
    _songBox.putMany(songs);
  }
}
