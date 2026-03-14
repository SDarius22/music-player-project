import 'package:music_player_frontend/core/entities/playlist.dart';

abstract class PlaylistRepository {
  Stream watchPlaylists();

  Map<String, dynamic> get sortFields;

  Playlist savePlaylist(Playlist playlist);

  Playlist? getPlaylistByName(String name);

  Playlist? getPlaylist(int id);

  List<Playlist> getIndestructiblePlaylists();

  List<Playlist> getNormalPlaylists();

  List<Playlist> getAllPlaylists();

  List<Playlist> getPlaylists(String query, String sortField, bool ascending);

  void deletePlaylist(Playlist playlist);
}
