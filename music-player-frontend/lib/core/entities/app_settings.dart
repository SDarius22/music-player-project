import 'package:music_player_frontend/core/entities/abstract/abstract_persistent_entity.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppSettings extends PersistentEntity<AppSettings> {
  @Id()
  int id = 0;

  final user = ToOne<User>();

  bool firstTime = true;
  bool systemTray = true;
  bool fullClose = false;

  String mainSongPlace = '';

  List<String> songPlaces = [];
  List<int> songPlaceIncludeSubfolders = [];

  List<String> missingSongs = []; //TBD

  void save() {
    super.persist(this);
  }
}
