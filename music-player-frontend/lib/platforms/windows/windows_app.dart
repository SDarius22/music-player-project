import 'package:flutter/widgets.dart';
import 'package:music_player_frontend/app/native_music_player_app.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/windows/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/windows/services/windows_file_service.dart';
import 'package:music_player_frontend/platforms/windows/services/windows_music_scanner_service.dart';
import 'package:provider/provider.dart';

class WindowsApp extends NativeMusicPlayerApp {
  const WindowsApp({super.key});

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
    return WindowsMusicScannerService(
      context.read<LocalTrackService>(),
      context.read<AbstractFileService>(),
      context.read<SettingsService>(),
    );
  }

  @override
  AbstractFileService createFileService(BuildContext context) {
    return WindowsFileService();
  }
}
