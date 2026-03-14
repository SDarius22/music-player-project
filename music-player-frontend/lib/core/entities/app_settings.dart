import 'package:music_player_frontend/core/database/persistence/objectbox_annotations.dart';

@Entity()
class AppSettings {
  @Id()
  int id = 0;

  bool firstTime = true;
  bool systemTray = true;
  bool fullClose = false;
  bool drawerOpen = true;

  String mainSongPlace = '';

  List<String> songPlaces = [];
  List<int> songPlaceIncludeSubfolders = [];

  AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final appSettings = AppSettings();
    appSettings.firstTime = (json['firstTime'] as bool?) ?? true;
    appSettings.systemTray = (json['systemTray'] as bool?) ?? true;
    appSettings.fullClose = (json['fullClose'] as bool?) ?? false;
    appSettings.drawerOpen = (json['drawerOpen'] as bool?) ?? true;
    appSettings.mainSongPlace = (json['mainSongPlace'] as String?) ?? '';
    appSettings.songPlaces =
        (json['songPlaces'] as List?)?.map((e) => e.toString()).toList() ?? [];
    appSettings.songPlaceIncludeSubfolders =
        (json['songPlaceIncludeSubfolders'] as List?)
            ?.map((e) => int.tryParse(e.toString()) ?? 0)
            .toList() ??
        [];
    return appSettings;
  }

  Map<String, dynamic> toJson() => {
    'firstTime': firstTime,
    'systemTray': systemTray,
    'fullClose': fullClose,
    'drawerOpen': drawerOpen,
    'mainSongPlace': mainSongPlace,
    'songPlaces': songPlaces,
    'songPlaceIncludeSubfolders': songPlaceIncludeSubfolders,
  };
}
