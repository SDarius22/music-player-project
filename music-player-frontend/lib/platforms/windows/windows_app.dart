import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/ui/abstract_app.dart';
import 'package:music_player_frontend/platforms/windows/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/windows/services/windows_file_service.dart';
import 'package:music_player_frontend/platforms/windows/services/windows_music_scanner_service.dart';
import 'package:provider/provider.dart';

class WindowsApp extends AbstractApp {
  const WindowsApp({super.key});

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) =>
      AppStateProvider(
        context.read<AudioProvider>(),
        context.read<HealthService>(),
        context.read<SettingsService>(),
      );

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) =>
      WindowsMusicScannerService(
        context.read<SongService>(),
        context.read<ArtistService>(),
        context.read<AlbumService>(),
        context.read<AbstractFileService>(),
        context.read<SettingsService>(),
      );

  @override
  AbstractFileService createFileService(BuildContext context) =>
      WindowsFileService();
}
