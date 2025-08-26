import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';

class PlaylistRepository {
  Box<Playlist> get _playlistBox => ObjectBox.store.box<Playlist>();

  Playlist savePlaylist(Playlist playlist)  {
    playlist.id = _playlistBox.put(playlist);
    return playlist;
  }

  Stream watchPlaylists() => _playlistBox.query().watch(triggerImmediately: true);

  Playlist? getPlaylistByName(String name) {
    return _playlistBox.query(Playlist_.name.equals(name)).build().findUnique();
  }

  Playlist? getPlaylist(int id) {
    return _playlistBox.get(id);
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistBox.query(Playlist_.indestructible.equals(true)).order(Playlist_.name).build().find();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistBox.query(Playlist_.indestructible.equals(false)).order(Playlist_.name).build().find();
  }

  List<Playlist> getAllPlaylists()  {
    return _playlistBox.query().order(Playlist_.indestructible, flags: Order.descending).order(Playlist_.name).build().find();
  }

  List<Playlist> getPlaylists(String query, String sortField, bool flag) {
    Query<Playlist> builderQuery;
    if (flag == false) {
      builderQuery = _playlistBox
          .query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
      ).build();
    } else {
      builderQuery = _playlistBox
          .query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  void deletePlaylist(Playlist playlist)  {
    _playlistBox.remove(playlist.id);
  }
}