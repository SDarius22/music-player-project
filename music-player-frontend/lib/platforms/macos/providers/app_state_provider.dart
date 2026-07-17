import 'package:flutter/services.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'package:music_player_frontend/platforms/desktop/providers/desktop_app_state_provider.dart';

class AppStateProvider extends DesktopAppStateProvider with FullScreenListener {
  AppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService,
  ) : super(trayIcon: 'assets/logo.png', setTrayTitle: false) {
    FullScreen.addListener(this);
  }

  @override
  void onFullScreenChanged(bool enabled, SystemUiMode? systemUiMode) {
    isFullScreen = enabled;
    notifyListeners();
  }
}
