import 'package:music_player_frontend/core/entities/local_track.dart';

abstract class LocalTrackRepository {
  LocalTrack? getBySourceKey(String sourceKey);

  List<LocalTrack> getAll();

  void save(LocalTrack track);

  void saveMany(List<LocalTrack> tracks);

  Stream<List<LocalTrack>> watch();

  void clearAll();
}
