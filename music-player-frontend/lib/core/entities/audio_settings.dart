import 'package:collection/collection.dart';
import 'package:music_player_frontend/core/entities/queue_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AudioSettings {
  @Id()
  int id = 0;

  int index = 0;
  int slider = 0; // this is the time in milliseconds

  @Transient()
  bool playing = false;

  bool repeat = false;
  bool shuffle = false;

  double balance = 0;
  double speed = 1;
  double volume = 0.5;

  final songs = ToMany<QueueSong>();

  List<QueueSong> get queueSongs => songs.sortedBy((e) => e.position).toList();

  List<Song> get queue =>
      songs
          .sortedBy((e) => e.position)
          .map((e) => e.song.target)
          .whereType<Song>()
          .toList();

  List<Song> get shuffledQueue {
    List<Song> shuffled = List.from(queue);
    shuffled.shuffle();
    return shuffled;
  }

  List<Song> get currentQueue => shuffle ? shuffledQueue : queue;

  int get currentIndexInNonShuffled =>
      currentQueue.isNotEmpty ? queue.indexOf(currentQueue[index]) : -1;

  Song get currentSong =>
      currentQueue.isNotEmpty ? currentQueue[index] : Song();

  Song get nextSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(index + 1) % currentQueue.length]
          : Song();

  set currentSong(Song song) {
    int newIndex = currentQueue.indexOf(song);
    if (newIndex != -1) {
      index = newIndex;
    }
  }

  Song get previousSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(index - 1 + currentQueue.length) %
              currentQueue.length]
          : Song();
}
