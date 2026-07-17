import 'package:music_player_frontend/platforms/desktop/providers/desktop_app_state_provider.dart';

class AppStateProvider extends DesktopAppStateProvider {
  AppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService,
  ) : super(trayIcon: 'assets/logo.ico');
}
