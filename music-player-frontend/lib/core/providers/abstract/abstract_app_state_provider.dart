import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:universal_platform/universal_platform.dart';

abstract class AbstractAppStateProvider with ChangeNotifier {
  final AudioProvider audioProvider;
  final HealthService healthService;
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

  ValueNotifier<bool> isPanelOpen = ValueNotifier(false);
  ValueNotifier<double> opacityNotifier = ValueNotifier(1.0);
  ValueNotifier<int> refreshRequestNotifier = ValueNotifier(0);

  ValueNotifier<bool> shouldDisplayLocalOnly = ValueNotifier(false);
  ValueNotifier<Widget> connectivityStatusNotifier = ValueNotifier(
    const Tooltip(
      message: "Checking connectivity...",
      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.grey),
    ),
  );

  AbstractAppStateProvider(
    this.audioProvider,
    this.healthService,
    this.settingsService,
  ) {
    _initialize();
  }

  List<Color> get colors {
    if (audioProvider.currentSong == null ||
        audioProvider.currentSong!.getColors().isEmpty ||
        audioProvider.currentSong!.getColors().length != 4) {
      return MusicPlayerTheme.primaryGradient.colors;
    }

    return audioProvider.currentSong!.getColors();
  }

  void requestRefresh() {
    refreshRequestNotifier.value++;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    appSettings = settingsService.getAppSettings();

    if (!UniversalPlatform.isWeb) {
      Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> result,
      ) {
        if (result.contains(ConnectivityResult.none)) {
          connectivityStatusNotifier.value = const Tooltip(
            message: "No Internet Connection",
            child: Icon(Icons.signal_cellular_off, color: Colors.red),
          );
          shouldDisplayLocalOnly.value = true;
          return;
        }

        if (!healthService.isHealthy.value) {
          connectivityStatusNotifier.value = const Tooltip(
            message: "Server is unreachable",
            child: Icon(Icons.error_outline, color: Colors.red),
          );
          shouldDisplayLocalOnly.value = true;
          return;
        }

        if (result.contains(ConnectivityResult.wifi)) {
          connectivityStatusNotifier.value = const Tooltip(
            message: "Connected to Wi-Fi",
            child: Icon(Icons.wifi, color: Colors.green),
          );
          shouldDisplayLocalOnly.value = false;
          return;
        }

        if (result.contains(ConnectivityResult.mobile)) {
          connectivityStatusNotifier.value = const Tooltip(
            message: "Connected to Mobile Data",
            child: Icon(Icons.signal_cellular_4_bar, color: Colors.orange),
          );
          shouldDisplayLocalOnly.value = false;
          return;
        }

        connectivityStatusNotifier.value = const Tooltip(
          message: "No Internet Connection",
          child: Icon(Icons.signal_cellular_off, color: Colors.red),
        );
        shouldDisplayLocalOnly.value = true;
      });
    }

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
