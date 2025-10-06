import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class PlayedSong {
  @Id()
  int id = 0;

  final song = ToOne<Song>();
  DateTime playedAt = DateTime.now();
}
