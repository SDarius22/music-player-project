import 'package:music_player_frontend/app/state/app_state_provider.dart';

class AppStateProvider extends AbstractAppStateProvider {
  AppStateProvider(
    super.audioProvider,
    super.healthService,
    super.settingsService,
  );
}
