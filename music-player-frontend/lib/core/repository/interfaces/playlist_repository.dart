import 'package:music_player_frontend/core/entities/playlist.dart';

abstract class PlaylistRepository {
  Stream watchPlaylists();

  Map<String, dynamic> get sortFields;

  Playlist savePlaylist(Playlist playlist);

  Playlist? getPlaylistByName(String name);

  Playlist getOrCreatePlaylist(String name);

  int getPlaylistCount(String query, bool containLocalOnly);

  List<Playlist> getIndestructiblePlaylists(int offset, int limit);

  int getIndestructiblePlaylistCount();

  List<Playlist> getNormalPlaylists(int offset, int limit);

  int getNormalPlaylistCount();

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
