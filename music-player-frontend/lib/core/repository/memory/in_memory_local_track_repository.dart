import 'dart:async';

import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';

class InMemoryLocalTrackRepository implements LocalTrackRepository {
  final Map<String, LocalTrack> _tracks = {};
  int _nextId = 1;
  final StreamController<List<LocalTrack>> _changes =
      StreamController<List<LocalTrack>>.broadcast();

  void _notify() => _changes.add(getAll());

  @override
  LocalTrack? getBySourceKey(String sourceKey) => _tracks[sourceKey];

  @override
  List<LocalTrack> getAll() => List.unmodifiable(_tracks.values);

  @override
  void save(LocalTrack track) {
    if (track.id == 0) {
      track.id = _nextId++;
    } else if (track.id >= _nextId) {
      _nextId = track.id + 1;
    }
    _tracks[track.sourceKey] = track;
    _notify();
  }

  @override
  void saveMany(List<LocalTrack> tracks) {
    for (final track in tracks) {
      if (track.id == 0) {
        track.id = _nextId++;
      } else if (track.id >= _nextId) {
        _nextId = track.id + 1;
      }
      _tracks[track.sourceKey] = track;
    }
    _notify();
  }

  @override
  Stream<List<LocalTrack>> watch() async* {
    yield getAll();
    yield* _changes.stream;
  }
}
