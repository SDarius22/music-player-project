import 'package:objectbox/objectbox.dart';
import 'package:music_player_frontend/core/entities/user.dart';

@Entity()
class AppSettings {
  @Id()
  int id = 0;

  final user = ToOne<User>();

  List<String> missingSongs = []; //TBD
}