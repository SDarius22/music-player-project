import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/queue_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';

class QueueSongRepository {
  Box<QueueSong> get _queueSongBox => ObjectBox.store.box<QueueSong>();

  Stream watchQueueSongs() =>
      _queueSongBox.query().watch(triggerImmediately: true);

  QueueSong saveQueueSong(QueueSong queueSong) {
    queueSong.id = _queueSongBox.put(queueSong);
    return queueSong;
  }

  void saveAllQueueSongs(List<Song> songs) {
    try {
      double position = 0.0;
      for (var song in songs) {
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position = position++;
        _queueSongBox.put(queueSong);
      }
    } catch (e) {
      throw Exception("Error saving multiple queue songs: $e");
    }
  }

  void deleteSongFromQueue(Song song) {
    try {
      QueueSong? queueSong =
          _queueSongBox
              .query(QueueSong_.song.equals(song.id))
              .build()
              .findFirst();
      if (queueSong != null) {
        _queueSongBox.remove(queueSong.id);
      }
    } catch (e) {
      throw Exception("Error deleting queue song ${song.path}: $e");
    }
  }

  void clearQueue() {
    try {
      _queueSongBox.removeAll();
    } catch (e) {
      throw Exception("Error clearing queue: $e");
    }
  }
}
