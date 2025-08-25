import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';

class PlaylistRepository {
  get playlistBox => ObjectBox.store.box<Playlist>();

  void addPlaylist(Playlist playlist)  {
    playlistBox.put(playlist);
  }

  Stream watchAllPlaylists()  {
    final query = playlistBox._query();
    return query.watch();
  }

  Playlist? getPlaylist(String name)  {
    return playlistBox._query(Playlist_.name.equals(name)).build().findUnique();
  }

  List<Playlist> getIndestructiblePlaylists()  {
    return playlistBox
        ._query(Playlist_.indestructible.equals(true))
        .order(Playlist_.name)
        .build()
        .find();
  }

  List<Playlist> getNormalPlaylists()  {
    return playlistBox
        ._query(Playlist_.indestructible.equals(false))
        .order(Playlist_.name)
        .build()
        .find();
  }

  List<Playlist> getAllPlaylists()  {
    return playlistBox._query().order(Playlist_.indestructible, flags: Order.descending).order(Playlist_.name).build().find();
  }

  List<Playlist> getPlaylists(String query, String sortField, bool flag)  {
    Query<Playlist> builderQuery;
    if (flag == false) {
      builderQuery = playlistBox
          ._query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
      ).build();
    } else {
      builderQuery = playlistBox
          ._query(Playlist_.name.contains(query, caseSensitive: false))
          .order(Playlist_.indestructible, flags: Order.descending)
          .order(
        sortField == 'Name' ? Playlist_.name : Playlist_.createdAt,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  void deletePlaylist(Playlist playlist)  {
    playlistBox.remove(playlist.id);
  }

  void updatePlaylist(Playlist playlist)  {
    playlistBox.put(playlist);
  }
}