import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class QueueSong {
  @Id()
  int id = 0;

  final song = ToOne<Song>();
  double position = 0.0; // Position in the queue
}
