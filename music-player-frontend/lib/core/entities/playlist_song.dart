import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class PlaylistSong {
  @Id()
  int id = 0;

  final playlist = ToOne<Playlist>();
  final song = ToOne<Song>();

  int order = 0; // Order of the song in the playlist
}
