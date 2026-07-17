import 'package:bot_toast/bot_toast.dart';
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
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/android/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/android/services/android_file_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:provider/provider.dart';

class AndroidApp extends AbstractApp {
  const AndroidApp({super.key});

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) =>
      AppStateProvider(
        context.read<AudioProvider>(),
        context.read<HealthService>(),
        context.read<SettingsService>(),
      );

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) =>
      AndroidMusicScannerService(
        context.read<SongService>(),
        context.read<ArtistService>(),
        context.read<AlbumService>(),
        context.read<AbstractFileService>(),
      );

  @override
  AbstractFileService createFileService(BuildContext context) =>
      AndroidFileService();

  @override
  Widget getAppWidget(BuildContext context) {
    final appState = context.read<AbstractAppStateProvider>();
    return MaterialApp(
      navigatorKey: appState.outerNavigatorKey,
      builder:
          (context, child) => BotToastInit()(context, responsiveBuilder(child)),
      debugShowCheckedModeBanner: false,
      checkerboardOffscreenLayers: true,
      theme: MusicPlayerTheme.getTheme(),
      home: const SafeArea(child: LoadingScreen()),
    );
  }
}
