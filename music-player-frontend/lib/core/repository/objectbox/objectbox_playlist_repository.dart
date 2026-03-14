import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';

class ObjectBoxPlaylistRepository implements PlaylistRepository {
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
    playlist.id = _playlistBox.put(playlist);
    return playlist;
  }

  @override
  Playlist? getPlaylistByName(String name) {
    return _playlistBox.query(Playlist_.name.equals(name)).build().findUnique();
  }

  @override
  Playlist? getPlaylist(int id) {
    return _playlistBox.get(id);
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
        .query(Playlist_.indestructible.equals(false))
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
  List<Playlist> getPlaylists(String query, String sortField, bool ascending) {
    Query<Playlist> builderQuery;
    if (ascending) {
      builderQuery =
          _playlistBox
              .query(Playlist_.name.contains(query, caseSensitive: false))
              .order(Playlist_.indestructible, flags: Order.descending)
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Playlist_.name,
              )
              .build();
    } else {
      builderQuery =
          _playlistBox
              .query(Playlist_.name.contains(query, caseSensitive: false))
              .order(Playlist_.indestructible, flags: Order.descending)
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Playlist_.name,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  @override
  void deletePlaylist(Playlist playlist) {
    _playlistBox.remove(playlist.id);
  }
}
