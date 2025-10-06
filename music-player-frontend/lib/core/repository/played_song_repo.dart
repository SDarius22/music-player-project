import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/played_song.dart';

class PlayedSongRepository {
  Box<PlayedSong> get _playedSongBox => ObjectBox.store.box<PlayedSong>();

  Stream watchPlayedSongs() =>
      _playedSongBox.query().watch(triggerImmediately: true);

  PlayedSong savePlayedSong(PlayedSong playedSong) {
    playedSong.id = _playedSongBox.put(playedSong);
    return playedSong;
  }

  List<PlayedSong> getAllPlayedSongs() {
    try {
      return _playedSongBox
          .query()
          .order(PlayedSong_.playedAt, flags: Order.descending)
          .build()
          .find();
    } catch (e) {
      throw Exception("Error retrieving played songs: $e");
    }
  }

  List<PlayedSong> getRecentPlayedSongs(int limit) {
    try {
      return _playedSongBox
          .query()
          .order(PlayedSong_.playedAt, flags: Order.descending)
          .build()
          .find()
          .take(limit)
          .toList();
    } catch (e) {
      throw Exception("Error retrieving recent played songs: $e");
    }
  }

  List<PlayedSong> getMostPlayedSongs(int limit) {
    try {
      final query = _playedSongBox.query();
      final playedSongs = query.build().find();
      final songCount = <int, int>{};

      for (var playedSong in playedSongs) {
        final songId = playedSong.song.target?.id;
        if (songId != null) {
          songCount[songId] = (songCount[songId] ?? 0) + 1;
        }
      }

      final sortedSongs =
          songCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      final mostPlayedSongIds =
          sortedSongs.take(limit).map((e) => e.key).toSet();

      return playedSongs
          .where(
            (ps) =>
                ps.song.target != null &&
                mostPlayedSongIds.contains(ps.song.target!.id),
          )
          .toList();
    } catch (e) {
      throw Exception("Error retrieving most played songs: $e");
    }
  }
}
