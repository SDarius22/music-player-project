import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_audio_player.dart';
import 'package:music_player_frontend/core/providers/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/app_state_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/platforms/linux/entities/concrete_audio_player.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

class LinuxApp extends StatelessWidget {
  const LinuxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AbstractAudioPlayer>(
          create: (context) => ConcreteAudioPlayer(),
        ),

        Provider<SettingsService>(
          create: (context) => SettingsService(),
        ),
        Provider<AlbumService>(
          create: (context) => AlbumService(),
        ),
        Provider<ArtistService>(
          create: (context) => ArtistService(),
        ),

        Provider<PlaylistService>(
          create: (context) => PlaylistService(),
        ),
        Provider<SongService>(
          create: (context) => SongService(
            context.read<PlaylistService>(),
          ),
        ),

        ChangeNotifierProvider<AlbumProvider> (
          create: (context) => AlbumProvider(context.read<AlbumService>()),
        ),
        ChangeNotifierProvider<ArtistProvider> (
          create: (context) => ArtistProvider(context.read<ArtistService>()),
        ),
        ChangeNotifierProvider<AbstractAudioProvider>(
            create: (context) => AudioProvider()// ..init(context.read<SettingsService>()),
        ),
        ChangeNotifierProvider<PlaylistProvider> (
          create: (context) => PlaylistProvider(context.read<PlaylistService>()),
        ),
        ChangeNotifierProvider<SongProvider> (
          create: (context) => SongProvider(context.read<SongService>()),
        ),
        ChangeNotifierProvider<LyricsProvider>(
          create: (context) => LyricsProvider(context.read<AbstractAudioProvider>()),
        ),
        ChangeNotifierProvider<AbstractAppStateProvider>(
          create: (context) => AppStateProvider(context.read<AudioProvider>(), context.read<SettingsService>()),
        ),

      ],
      child: MaterialApp(
        builder: BotToastInit(),
        debugShowCheckedModeBanner: false,
        checkerboardOffscreenLayers: true,
        home: const LoadingScreen(),
      ),
    );
  }
}