import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';

class ObjectBoxPlaylistRepository implements PlaylistRepository {
  static final _logger = Logger('ObjectBoxPlaylistRepository');

  Box<Playlist> get _playlistBox => ObjectBox.store.box<Playlist>();

  @override
  Stream watchPlaylists() =>
      _playlistBox.query().watch(triggerImmediately: true);

  @override
  Map<String, dynamic> get sortFields => {
    'Name': Playlist_.name,
    'Created At': Playlist_.createdAt,
  };

  @override
  Playlist savePlaylist(Playlist playlist) {
    try {
      playlist.id = _playlistBox.put(playlist);
    } catch (e) {
      _logger.warning('Failed to save playlist', e);
    }

    return playlist;
  }

  @override
  Playlist? getPlaylistByServerIdAndName(int serverId, String name) {
    return _playlistBox
        .query(
          Playlist_.serverId.equals(serverId) & Playlist_.name.equals(name),
        )
        .build()
        .findFirst();
  }

  @override
  int getPlaylistCount(String query, bool containLocalOnly) {
    var conditions = Playlist_.name.contains(query, caseSensitive: false);
    if (containLocalOnly) {
      conditions = conditions.and(Playlist_.isLocal.equals(true));
    }
    return _playlistBox.query(conditions).build().count();
  }

  @override
  Playlist getOrCreatePlaylist(int serverId, String name) {
    final existing = getPlaylistByServerIdAndName(serverId, name);
    if (existing != null) return existing;
    Playlist playlist = Playlist(name);
    playlist.serverId = serverId;
    return savePlaylist(playlist);
  }

  @override
  List<Playlist> getIndestructiblePlaylists() {
    return _playlistBox
        .query(Playlist_.indestructible.equals(true))
        .order(Playlist_.name)
        .build()
        .find();
  }

  @override
  List<Playlist> getNormalPlaylists() {
    return _playlistBox
        .query(
          Playlist_.indestructible.equals(false) |
              Playlist_.name.equals('Queue'),
        )
        .order(Playlist_.name)
        .build()
        .find();
  }

  @override
  List<Playlist> getAllPlaylists() {
    return _playlistBox
        .query()
        .order(Playlist_.indestructible, flags: Order.descending)
        .order(Playlist_.name)
        .build()
        .find();
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
    var conditions = Playlist_.name.contains(query, caseSensitive: false);
    if (containLocalOnly) {
      conditions = conditions.and(Playlist_.isLocal.equals(true));
    }
    final q =
        _playlistBox
            .query(conditions)
            .order(Playlist_.indestructible, flags: Order.descending)
            .order(
              sortFields.containsKey(sortField)
                  ? sortFields[sortField]
                  : Playlist_.name,
              flags: ascending ? 0 : Order.descending,
            )
            .build();
    q.offset = offset;
    q.limit = limit;
    return q.find();
  }

  @override
  void deletePlaylist(Playlist playlist) {
    _playlistBox.remove(playlist.id);
  }
}
