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

  // 0 = WiFi only, 1 = Cellular only, 2 = WiFi + Cellular (default)
  int peerNetworkMode = 2;
  // Data limit in GB; -1 = unlimited (min 1 when set)
  int peerWifiDataLimitGB = -1;
  int peerCellularDataLimitGB = -1;

  // Monthly P2P upload tracking (bytes uploaded to peers this month)
  int peerWifiUploadedBytesThisMonth = 0;
  int peerCellularUploadedBytesThisMonth = 0;
  // yyyyMM of the last reset, e.g. 202604
  int peerUploadResetMonth = 0;

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
    appSettings.peerNetworkMode = (json['peerNetworkMode'] as int?) ?? 2;
    appSettings.peerWifiDataLimitGB =
        (json['peerWifiDataLimitGB'] as int?) ?? -1;
    appSettings.peerCellularDataLimitGB =
        (json['peerCellularDataLimitGB'] as int?) ?? -1;
    appSettings.peerWifiUploadedBytesThisMonth =
        (json['peerWifiUploadedBytesThisMonth'] as int?) ?? 0;
    appSettings.peerCellularUploadedBytesThisMonth =
        (json['peerCellularUploadedBytesThisMonth'] as int?) ?? 0;
    appSettings.peerUploadResetMonth =
        (json['peerUploadResetMonth'] as int?) ?? 0;
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
    'peerNetworkMode': peerNetworkMode,
    'peerWifiDataLimitGB': peerWifiDataLimitGB,
    'peerCellularDataLimitGB': peerCellularDataLimitGB,
    'peerWifiUploadedBytesThisMonth': peerWifiUploadedBytesThisMonth,
    'peerCellularUploadedBytesThisMonth': peerCellularUploadedBytesThisMonth,
    'peerUploadResetMonth': peerUploadResetMonth,
  };
}
