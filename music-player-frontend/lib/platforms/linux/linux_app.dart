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
import 'package:music_player_frontend/platforms/linux/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/linux/services/linux_file_service.dart';
import 'package:music_player_frontend/platforms/linux/services/linux_music_scanner_service.dart';
import 'package:provider/provider.dart';

class LinuxApp extends AbstractApp {
  const LinuxApp({super.key});

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) =>
      AppStateProvider(
        context.read<AudioProvider>(),
        context.read<HealthService>(),
        context.read<SettingsService>(),
      );

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) =>
      LinuxMusicScannerService(
        context.read<SongService>(),
        context.read<ArtistService>(),
        context.read<AlbumService>(),
        context.read<AbstractFileService>(),
        context.read<SettingsService>(),
      );

  @override
  AbstractFileService createFileService(BuildContext context) =>
      LinuxFileService();
}
