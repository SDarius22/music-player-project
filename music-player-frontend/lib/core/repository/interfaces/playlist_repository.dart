import 'package:music_player_frontend/core/entities/playlist.dart';

abstract class PlaylistRepository {
  Stream watchPlaylists();

  Map<String, dynamic> get sortFields;

  Playlist savePlaylist(Playlist playlist);

  Playlist? getPlaylistByServerIdAndName(int serverId, String name);

  Playlist getOrCreatePlaylist(int serverId, String name);

  int getPlaylistCount(String query, bool containLocalOnly);

  List<Playlist> getIndestructiblePlaylists();

  List<Playlist> getNormalPlaylists();

  List<Playlist> getAllPlaylists();

  List<Playlist> getPlaylistsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  );

  void deletePlaylist(Playlist playlist);
}
