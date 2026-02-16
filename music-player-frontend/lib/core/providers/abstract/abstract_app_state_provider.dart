import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  final AudioProvider audioProvider;
  final SettingsService settingsService;

  final navigatorKey = GlobalKey<NavigatorState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final gradientController = AnimatedMeshGradientController();
  final miniPlayerController = MiniPlayerController();

  AppSettings appSettings = AppSettings();

  List<String> appActions = [];
  List<Color> colors = [
    Color(0xFF2A1B55),
    Color(0xFF000000),
    Color(0xFF000000),
    Color(0xFF2A1B55),
  ];

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);
  ValueNotifier<double> opacityNotifier = ValueNotifier(1.0);

  AbstractAppStateProvider(this.audioProvider, this.settingsService) {
    appSettings = settingsService.getAppSettings();
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
    settingsService.updateAppSettings(appSettings);
    notifyListeners();
  }

  void setDrawerOpen(bool isOpen) {
    appSettings.drawerOpen = isOpen;
    updateAppSettings();
    notifyListeners();
  }

  Future<void> setColors() async {
    if (audioProvider.currentSong.coverArt == Constants.logoBytes) {
      colors = MusicPlayerTheme.primaryGradient.colors;
      return;
    }
    colors = await WorkerService.extractColors(
      audioProvider.currentSong.coverArt,
    );
  }
}
