import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/app/music_player_app.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:music_player_frontend/app/widgets/loading_screen.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_album_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_artist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_chunk_stat_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_settings_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_song_repository.dart';
import 'package:music_player_frontend/core/repository/storage/io_chunk_cache_repo.dart';
import 'package:provider/provider.dart';

/// Shared composition root for native platforms backed by ObjectBox.
///
/// Platform subclasses only provide their scanner, file service, and app-state
/// implementation. Keeping repository wiring here prevents the six platform
/// entry points from drifting apart.
abstract class NativeMusicPlayerApp extends MusicPlayerApp {
  const NativeMusicPlayerApp({super.key});

  /// Android keeps the loading screen inside the system safe area.
  bool get useSafeAreaForLoading => false;

  @override
  List<InheritedProvider> platformProviders(BuildContext context) => [
    Provider<AlbumRepository>(create: (_) => ObjectBoxAlbumRepository()),
    Provider<ArtistRepository>(create: (_) => ObjectBoxArtistRepository()),
    Provider<PlaylistRepository>(create: (_) => ObjectBoxPlaylistRepository()),
    Provider<SongRepository>(create: (_) => ObjectBoxSongRepository()),
    Provider<LocalTrackRepository>(
      create: (_) => ObjectBoxLocalTrackRepository(),
    ),
    Provider<ChunkCacheRepository>(create: (_) => IOChunkCacheRepository()),
    Provider<ChunkStatRepository>(
      create: (_) => ObjectBoxChunkStatRepository(),
    ),
    Provider<SettingsRepository>(create: (_) => ObjectBoxSettingsRepository()),
  ];

  @override
  Widget getAppWidget(BuildContext context) {
    final appState = context.read<AbstractAppStateProvider>();
    final loadingScreen =
        useSafeAreaForLoading
            ? const SafeArea(child: LoadingScreen())
            : const LoadingScreen();

    return MaterialApp(
      navigatorKey: appState.outerNavigatorKey,
      builder:
          (context, child) => BotToastInit()(context, responsiveBuilder(child)),
      debugShowCheckedModeBanner: false,
      checkerboardOffscreenLayers: true,
      theme: MusicPlayerTheme.getTheme(),
      home: loadingScreen,
    );
  }
}
