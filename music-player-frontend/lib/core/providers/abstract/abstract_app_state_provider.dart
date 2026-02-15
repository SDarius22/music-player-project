import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  final AudioProvider audioProvider;
  final SettingsService settingsService;

  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final gradientController = AnimatedMeshGradientController();
  final miniPlayerController = MiniPlayerController();

  AppSettings get appSettings => settingsService.currentAppSettings;

  List<String> appActions = [];
  List<Color> colors = [
    Colors.black,
    Colors.black12,
    Colors.black26,
    Colors.black38,
  ];

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);
  ValueNotifier<double> opacityNotifier = ValueNotifier(1.0);

  AbstractAppStateProvider(this.audioProvider, this.settingsService) {
    audioProvider.playingNotifier.addListener(() async {
      if (audioProvider.playingNotifier.value) {
        gradientController.start();
      } else {
        gradientController.stop();
      }
    });

    audioProvider.currentSongNotifier.addListener(() {
      setColors();
      notifyListeners();
    });
  }

  Future<void> addAppAction(String action) async {
    if (!appActions.contains(action)) {
      appActions.add(action);
      notifyListeners();
    }
  }

  void updateAppSettings() {
    settingsService.updateAppSettings();
    notifyListeners();
  }

  void setDrawerOpen(bool isOpen) {
    settingsService.currentAppSettings.drawerOpen = isOpen;
    updateAppSettings();
    notifyListeners();
  }

  Future<void> setColors() async {
    colors = await WorkerService.extractColors(
      audioProvider.currentSong.coverArt,
    );
  }
}
