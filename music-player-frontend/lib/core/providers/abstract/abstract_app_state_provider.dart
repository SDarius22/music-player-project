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
  bool _isInitialized = false;

  int currentDrawerIndex = 0;

  List<Color> get colors {
    if (audioProvider.currentSong == null ||
        audioProvider.currentSong!.getColors().isEmpty ||
        audioProvider.currentSong!.getColors().length != 4) {
      return MusicPlayerTheme.primaryGradient.colors;
    }

    return audioProvider.currentSong!.getColors();
  }

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);
  ValueNotifier<double> opacityNotifier = ValueNotifier(1.0);
  ValueNotifier<int> refreshRequestNotifier = ValueNotifier(0);

  void requestRefresh() {
    refreshRequestNotifier.value++;
  }

  AbstractAppStateProvider(this.audioProvider, this.settingsService) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
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

  Widget? getEndDrawer(BuildContext context) {
    return null;
  }
}
