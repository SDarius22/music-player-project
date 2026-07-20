// coverage:ignore-file

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:miniplayer/miniplayer.dart';
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _connectivityResults = const [];
  VoidCallback? _healthListener;
  VoidCallback? _audioProviderListener;
  VoidCallback? _currentSongListener;
  VoidCallback? _playingListener;

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

  void resetSessionState() {
    appSettings = AppSettings();
    currentDrawerIndex = 0;
    shouldDisplayLocalOnly.value = false;
    isPanelOpen.value = false;
    requestRefresh();
    notifyListeners();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    appSettings = settingsService.getAppSettings();

    _healthListener = _updateConnectivityStatus;
    healthService.isHealthy.addListener(_healthListener!);

    if (UniversalPlatform.isWeb) {
      _updateConnectivityStatus();
    } else {
      final connectivity = Connectivity();
      _connectivitySubscription = connectivity.onConnectivityChanged.listen((
        results,
      ) {
        _connectivityResults = results;
        _updateConnectivityStatus();
      });
      _connectivityResults = await connectivity.checkConnectivity();
      _updateConnectivityStatus();
    }

    _currentSongListener = () {
      notifyListeners();
    };
    audioProvider.currentSongNotifier.addListener(_currentSongListener!);

    _audioProviderListener = () {
      notifyListeners();
    };
    audioProvider.addListener(_audioProviderListener!);

    _playingListener = () {
      if (audioProvider.playingNotifier.value) {
        gradientController.start();
      } else {
        gradientController.stop();
      }
    };
    audioProvider.playingNotifier.addListener(_playingListener!);
  }

  void _updateConnectivityStatus() {
    final hasNetwork =
        UniversalPlatform.isWeb ||
        (_connectivityResults.isNotEmpty &&
            !_connectivityResults.contains(ConnectivityResult.none));

    if (!hasNetwork) {
      connectivityStatusNotifier.value = const Tooltip(
        message: "No Internet Connection",
        child: Icon(FluentIcons.signalCellularOff, color: Colors.red),
      );
      shouldDisplayLocalOnly.value = true;
      return;
    }

    if (!healthService.isHealthy.value) {
      connectivityStatusNotifier.value = const Tooltip(
        message: "Server is unreachable",
        child: Icon(FluentIcons.error, color: Colors.red),
      );
      shouldDisplayLocalOnly.value = true;
      return;
    }

    if (_connectivityResults.contains(ConnectivityResult.mobile)) {
      connectivityStatusNotifier.value = const Tooltip(
        message: "Connected to Mobile Data",
        child: Icon(FluentIcons.signalCellularOn, color: Colors.orange),
      );
    } else if (_connectivityResults.contains(ConnectivityResult.wifi)) {
      connectivityStatusNotifier.value = const Tooltip(
        message: "Connected to Wi-Fi",
        child: Icon(FluentIcons.wifi, color: Colors.green),
      );
    } else {
      connectivityStatusNotifier.value = const Tooltip(
        message: "Connected",
        child: Icon(FluentIcons.wifi, color: Colors.green),
      );
    }
    shouldDisplayLocalOnly.value = false;
  }

  @override
  void dispose() {
    if (_currentSongListener != null) {
      audioProvider.currentSongNotifier.removeListener(_currentSongListener!);
    }
    if (_audioProviderListener != null) {
      audioProvider.removeListener(_audioProviderListener!);
    }
    if (_playingListener != null) {
      audioProvider.playingNotifier.removeListener(_playingListener!);
    }
    _connectivitySubscription?.cancel();
    if (_healthListener != null) {
      healthService.isHealthy.removeListener(_healthListener!);
    }
    super.dispose();
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
