import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/playlist_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class PlaylistSongRepository {
  Box<PlaylistSong> get _playlistSongBox => ObjectBox.store.box<PlaylistSong>();

  Stream watchPlaylistSongs() =>
      _playlistSongBox.query().watch(triggerImmediately: true);

  PlaylistSong savePlaylistSong(PlaylistSong playlistSong) {
    playlistSong.id = _playlistSongBox.put(playlistSong);
    return playlistSong;
  }

  List<PlaylistSong> getPlaylistSongs(int playlistId) {
    try {
      return _playlistSongBox
          .query(PlaylistSong_.playlist.equals(playlistId))
          .order(PlaylistSong_.order)
          .build()
          .find();
    } catch (e) {
      throw Exception("Error retrieving songs for playlist $playlistId: $e");
    }
  }

  void deletePlaylistSong(Song song, int playlistId) {
    try {
      final playlistSong =
          _playlistSongBox
              .query(
                PlaylistSong_.song.equals(song.id) &
                    PlaylistSong_.playlist.equals(playlistId),
              )
              .build()
              .findFirst();
      if (playlistSong == null) {
        throw Exception("Song ${song.id} not found in playlist $playlistId");
      }
      playlistSong.playlist.target?.playlistSongs.remove(playlistSong);
      _playlistSongBox.remove(playlistSong.id);
    } catch (e) {
      throw Exception(
        "Error deleting song ${song.id} from playlist $playlistId: $e",
      );
    }
  }
}
