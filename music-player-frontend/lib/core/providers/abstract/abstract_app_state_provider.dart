import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  final AudioProvider audioProvider;
  final SettingsService settingsService;

  final innerNavigatorKey = GlobalKey<NavigatorState>();
  final outerNavigatorKey = GlobalKey<NavigatorState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final gradientController = AnimatedMeshGradientController();
  final miniPlayerController = MiniPlayerController();

  AppSettings appSettings = AppSettings();

  List<String> appActions = [];

  bool isFullScreen = false;

  List<Color> get colors =>
      audioProvider.currentSong.colors.isNotEmpty &&
              audioProvider.currentSong.colors.length == 4
          ? audioProvider.currentSong.colors
          : MusicPlayerTheme.primaryGradient.colors;

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);
  ValueNotifier<double> opacityNotifier = ValueNotifier(1.0);

  AbstractAppStateProvider(this.audioProvider, this.settingsService) {
    appSettings = settingsService.getAppSettings();
    audioProvider.currentSongNotifier.addListener(() {
      notifyListeners();
    });

    audioProvider.playingNotifier.addListener(() {
      if (audioProvider.playingNotifier.value) {
        gradientController.start();
      } else {
        gradientController.stop();
      }
    });
  }

  Future<void> addAppAction(String action) async {
    if (!appActions.contains(action)) {
      appActions.add(action);
      notifyListeners();
    }
  }

  void updateAppSettings() {
    settingsService.updateAppSettings(appSettings);
    notifyListeners();
  }

  void setDrawerOpen(bool isOpen) {
    appSettings.drawerOpen = isOpen;
    updateAppSettings();
    notifyListeners();
  }
}
