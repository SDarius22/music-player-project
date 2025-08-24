import 'package:music_player_frontend/core/entities/song.dart';
import 'package:objectbox/objectbox.dart';

mixin AbstractCollection {
  ToMany<Song> get songs;
}
