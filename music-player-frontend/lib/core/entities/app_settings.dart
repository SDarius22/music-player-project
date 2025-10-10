import 'package:objectbox/objectbox.dart';

@Entity()
class AppSettings {
  @Id()
  int id = 0;

  bool firstTime = true;
  bool systemTray = true;
  bool fullClose = false;
  bool drawerOpen = true;

  @Transient()
  bool initialScanComplete = false;

  String mainSongPlace = '';

  List<String> songPlaces = [];
  List<int> songPlaceIncludeSubfolders = [];
}
