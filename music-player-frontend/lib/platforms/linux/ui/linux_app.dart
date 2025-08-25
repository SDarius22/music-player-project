import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

class LinuxApp extends StatelessWidget {
  const LinuxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AlbumRepository>(
          create: (_) => AlbumRepository(),
        ),
        Provider<ArtistRepository>(
          create: (_) => ArtistRepository(),
        ),
        Provider<PlaylistRepository>(
          create: (_) => PlaylistRepository(),
        ),
        Provider<SettingsRepo>(
          create: (_) => SettingsRepo(),
        ),
        Provider<SongsRepository>(
          create: (_) => SongsRepository(),
        ),
        Provider<AlbumService>(
          create: (context) => AlbumService(context.read<AlbumRepository>()),
        ),
        Provider<ArtistService>(
          create: (context) => ArtistService(context.read<ArtistRepository>()),
        ),
        Provider<SettingsService>(
          create: (context) => SettingsService(context.read<SettingsRepo>()),
        ),
        Provider<SongService>(
          create: (context) => SongService(
              context.read<SongsRepository>(),
              context.read<SettingsService>(),
              context.read<AlbumService>(),
              context.read<ArtistService>()
          ),
        ),
        Provider<PlaylistService>(
          create: (context) => PlaylistService(context.read<PlaylistRepository>(), context.read<SongService>()),
        ),
        ChangeNotifierProvider<AlbumProvider> (
          create: (context) => AlbumProvider(context.read<AlbumService>()),
        ),
        ChangeNotifierProvider<ArtistProvider> (
          create: (context) => ArtistProvider(context.read<ArtistService>()),
        ),
        ChangeNotifierProvider<AudioProvider>(
            create: (context) => AudioProvider()// ..init(context.read<SettingsService>()),
        ),
        ChangeNotifierProvider<PlaylistProvider> (
          create: (context) => PlaylistProvider(context.read<PlaylistService>()),
        ),
        ChangeNotifierProvider<SongProvider> (
          create: (context) => SongProvider(context.read<SongService>()),
        ),
        ChangeNotifierProvider<LyricsProvider>(
          create: (context) => LyricsProvider(),
        ),
        ChangeNotifierProvider<AppStateProvider>(
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