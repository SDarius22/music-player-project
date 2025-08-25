import 'package:music_player_frontend/core/entities/user.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AudioSettings{
  @Id()
  int id = 0;
  ToOne<User> user = ToOne<User>();

  int index = 0;
  int slider = 0; // this is the time in milliseconds

  @Transient()
  bool playing = false;

  bool repeat = false;
  bool shuffle = false;

  double balance = 0;
  double speed = 1;
  double volume = 0.5;

  List<String> queue = [];
  List<String> shuffledQueue = [];

  get currentQueue => shuffle ? shuffledQueue : queue;

  get currentIndexInNonShuffled => currentQueue.isNotEmpty ? queue.indexOf(currentQueue[index]) : -1;

  get currentSong => currentQueue.isNotEmpty ? currentQueue[index] : null;

  get nextSong => currentQueue.isNotEmpty ? currentQueue[(index + 1) % currentQueue.length] : null;

  get previousSong => currentQueue.isNotEmpty ? currentQueue[(index - 1 + currentQueue.length) % currentQueue.length] : null;
}