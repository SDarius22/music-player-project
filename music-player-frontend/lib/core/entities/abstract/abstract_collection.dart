import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';
import 'package:music_player_frontend/core/entities/song.dart';

mixin AbstractCollection {
  ToMany<Song> get songs;
}
