import 'package:flutter/widgets.dart';
import 'package:music_player_frontend/app/native_music_player_app.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/android/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/android/services/android_file_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:provider/provider.dart';

class AndroidApp extends NativeMusicPlayerApp {
  const AndroidApp({super.key});

  @override
  bool get useSafeAreaForLoading => true;

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) {
    return AppStateProvider(
      context.read<AudioProvider>(),
      context.read<HealthService>(),
      context.read<SettingsService>(),
    );
  }

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) {
    return AndroidMusicScannerService(
      context.read<LocalTrackService>(),
      context.read<AbstractFileService>(),
    );
  }

  @override
  AbstractFileService createFileService(BuildContext context) {
    return AndroidFileService();
  }
}
