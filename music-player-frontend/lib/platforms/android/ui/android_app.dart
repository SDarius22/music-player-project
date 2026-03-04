import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/repository/album_repo.dart';
import 'package:music_player_frontend/core/repository/artist_repo.dart';
import 'package:music_player_frontend/core/repository/playlist_repo.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';
import 'package:music_player_frontend/core/repository/song_repo.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/android/services/android_file_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

import 'components/android_scaler.dart';

class AndroidApp extends StatelessWidget {
  const AndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Scaler>(create: (_) => AndroidScaler()),

        Provider<AlbumRepository>(create: (_) => AlbumRepository()),
        Provider<ArtistRepository>(create: (_) => ArtistRepository()),
        Provider<PlaylistRepository>(create: (_) => PlaylistRepository()),
        Provider<SettingsRepository>(create: (_) => SettingsRepository()),
        Provider<SongRepository>(create: (_) => SongRepository()),

        Provider<FileService>(create: (context) => AndroidFileService()),

        Provider<AlbumService>(
          create: (context) => AlbumService(context.read<AlbumRepository>()),
        ),
        Provider<ArtistService>(
          create: (context) => ArtistService(context.read<ArtistRepository>()),
        ),
        Provider<LyricsService>(create: (context) => LyricsService()),
        Provider<PlaylistService>(
          create:
              (context) => PlaylistService(
                context.read<PlaylistRepository>(),
                context.read<SongRepository>(),
              ),
        ),
        Provider<SettingsService>(
          create:
              (context) => SettingsService(context.read<SettingsRepository>()),
        ),
        Provider<SongService>(
          create: (context) => SongService(context.read<SongRepository>()),
        ),
        Provider<AbstractMusicScannerService>(
          create:
              (context) => MusicScannerService(
                context.read<SongService>(),
                context.read<ArtistService>(),
                context.read<AlbumService>(),
                context.read<FileService>(),
              ),
        ),
        Provider<AppAudioService>(
          create:
              (context) => AppAudioService(
                context.read<SongService>(),
                context.read<SettingsService>(),
                context.read<PlaylistService>(),
              ),
        ),

        ChangeNotifierProvider<AlbumProvider>(
          create: (context) => AlbumProvider(context.read<AlbumService>()),
          lazy: false,
        ),
        ChangeNotifierProvider<ArtistProvider>(
          create: (context) => ArtistProvider(context.read<ArtistService>()),
          lazy: false,
        ),
        ChangeNotifierProvider<PlaylistProvider>(
          create:
              (context) => PlaylistProvider(context.read<PlaylistService>()),
          lazy: false,
        ),
        ChangeNotifierProvider<SongProvider>(
          create:
              (context) => SongProvider(
                context.read<SongService>(),
                context.read<AbstractMusicScannerService>(),
              ),
          lazy: false,
        ),
        ChangeNotifierProvider<SelectionProvider>(
          create: (context) => SelectionProvider(),
        ),
        ChangeNotifierProvider<AudioProvider>(
          create: (context) {
            var audioProvider = AudioProvider(
              context.read<AppAudioService>(),
              context.read<FileService>(),
            );
            try {
              platform_service.AudioService.init(
                builder: () => audioProvider,
                config: const platform_service.AudioServiceConfig(
                  androidNotificationChannelId:
                      'com.example.music_player_frontend.channel.audio',
                  androidNotificationChannelName: 'Music Player',
                  androidNotificationOngoing: true,
                ),
              );
            } catch (e) {
              debugPrint('Error initializing AudioProvider: $e');
            }
            return audioProvider;
          },
        ),
        ChangeNotifierProvider<LyricsProvider>(
          create:
              (context) => LyricsProvider(
                context.read<AudioProvider>(),
                context.read<FileService>(),
              ),
          lazy: false,
        ),
        ChangeNotifierProvider<AbstractAppStateProvider>(
          create:
              (context) => AppStateProvider(
                context.read<AudioProvider>(),
                context.read<SettingsService>(),
              ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final appState = context.read<AbstractAppStateProvider>();

          return MaterialApp(
            navigatorKey: appState.outerNavigatorKey,
            builder: BotToastInit(),
            debugShowCheckedModeBanner: false,
            checkerboardOffscreenLayers: true,
            theme: MusicPlayerTheme.getDefaultTheme(),
            home: const SafeArea(child: LoadingScreen()),
          );
        },
      ),
    );
  }
}
