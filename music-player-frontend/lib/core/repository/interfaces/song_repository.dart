import 'package:music_player_frontend/core/entities/song.dart';

abstract class SongRepository {
  Stream watchSongs();

  Map<String, dynamic> get sortFields;

  Song saveSong(Song song);

  List<Song> saveSongs(List<Song> songs);

  int getSongCount(String query, bool localOnly);

  Song? getSongByFileHash(String fileHash);

  Song getOrCreateSong(String fileHash);

  Song? getMostRecentPlayedSong();

  List<Song> getRecentlyPlayedSongs(int limit);

  List<Song> getMostPlayedSongs(int limit);

  List<Song> getFavoriteSongs();

  List<Song> getSongsPaged(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int offset,
    int limit,
  );

  List<Song> getAllSongs();

  List<Song> getUnsyncedSongs();

  void deleteSong(Song song);

  void updateSong(Song song);

  void updateSongs(List<Song> songs);
}
