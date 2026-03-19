import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';

class ObjectBoxSongRepository implements SongRepository {
  Box<Song> get _songBox => ObjectBox.store.box<Song>();

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
  int getSongCount() {
    return _songBox.count();
  }

  @override
  Song getSongByPath(String path) {
    try {
      return _songBox.query(Song_.path.equals(path)).build().findFirst()!;
    } catch (e) {
      throw Exception('Song with path $path not found');
    }
  }

  @override
  Song? getSongByServerId(int serverId) {
    return _songBox.query(Song_.serverId.equals(serverId)).build().findFirst();
  }

  @override
  Song getSong(int id) {
    try {
      return _songBox.get(id)!;
    } catch (e) {
      throw Exception('Song with id $id not found');
    }
  }

  @override
  Song getSongContaining(String query) {
    try {
      return _songBox
          .query(Song_.path.contains(query, caseSensitive: false))
          .build()
          .findFirst()!;
    } catch (e) {
      throw Exception('Song containing $query not found');
    }
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
  List<Song> getSongs(String query, String sortField, bool ascending) {
    Query<Song> builderQuery;
    if (ascending) {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Song_.name,
              )
              .build();
    } else {
      builderQuery =
          _songBox
              .query(Song_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Song_.name,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  @override
  List<Song> getSongsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final q =
        _songBox
            .query(Song_.name.contains(query, caseSensitive: false))
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
  List<Song> getAllSongs() {
    return _songBox.query().order(Song_.name).build().find();
  }

  @override
  List<Song> getUnsyncedSongs() {
    return _songBox.query(Song_.requiresSync.equals(true)).build().find();
  }

  @override
  void markSongsAsSynced(List<int> serverIds) {
    for (final serverId in serverIds) {
      final song =
          _songBox.query(Song_.serverId.equals(serverId)).build().findFirst();
      if (song != null) {
        song.requiresSync = false;
        _songBox.put(song);
      }
    }
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
