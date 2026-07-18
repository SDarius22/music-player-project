import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';

class ObjectBoxLocalTrackRepository implements LocalTrackRepository {
  Box<LocalTrack> get _box => ObjectBox.store.box<LocalTrack>();

  @override
  LocalTrack? getBySourceKey(String sourceKey) =>
      _box.query(LocalTrack_.sourceKey.equals(sourceKey)).build().findFirst();

  @override
  List<LocalTrack> getAll() => _box.getAll();

  @override
  void save(LocalTrack track) {
    track.id = _box.put(track);
  }

  @override
  void saveMany(List<LocalTrack> tracks) {
    final ids = _box.putMany(tracks);
    for (var index = 0; index < tracks.length; index++) {
      tracks[index].id = ids[index];
    }
  }

  @override
  Stream<List<LocalTrack>> watch() =>
      _box.query().watch(triggerImmediately: true).map((query) => query.find());
}
