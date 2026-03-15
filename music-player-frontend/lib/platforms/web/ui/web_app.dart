import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/repository/storage/local_storage_settings_repository.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/streaming_rest_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/web_p2p_bridge.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:music_player_frontend/core/ui/abstract_app.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/web/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/web/services/web_file_service.dart';
import 'package:music_player_frontend/platforms/web/services/web_music_scanner_service.dart';
import 'package:music_player_frontend/platforms/web/ui/components/web_scaler.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class WebApp extends AbstractApp {
  const WebApp({super.key});

  @override
  List<InheritedProvider> platformProviders(BuildContext context) {
    return [
      Provider<AlbumRepository>(create: (_) => InMemoryAlbumRepository()),
      Provider<ArtistRepository>(create: (_) => InMemoryArtistRepository()),
      Provider<PlaylistRepository>(create: (_) => InMemoryPlaylistRepository()),
      Provider<SongRepository>(create: (_) => InMemorySongRepository()),
      Provider<ChunkCacheRepository>(
        create: (_) => InMemoryChunkCacheRepository(),
      ),
      Provider<SettingsRepository>(
        create: (_) => LocalStorageSettingsRepository(),
      ),
    ];
  }

  @override
  Widget getAppWidget(BuildContext context) {
    return MaterialApp(
      builder:
          (context, child) => BotToastInit()(
            context,
            ResponsiveBreakpoints.builder(
              child: child!,
              breakpoints: [
                const Breakpoint(start: 0, end: 450, name: MOBILE),
                const Breakpoint(start: 451, end: 800, name: TABLET),
                const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
            ),
          ),
      debugShowCheckedModeBanner: false,
      theme: MusicPlayerTheme.getDefaultTheme(),
      home: const LoadingScreen(),
    );
  }

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) {
    return AppStateProvider(
      context.read<AudioProvider>(),
      context.read<SettingsService>(),
    );
  }

  @override
  List<InheritedProvider> extraProviders(BuildContext context) {
    return [
      Provider<WebP2PBridge>(
        create:
            (context) => WebP2PBridge((int songId) {
              final manager = ChunkService(
                songId: songId,
                cacheRepo: context.read<ChunkCacheRepository>(),
                streamingClient: context.read<StreamingRestService>(),
                webrtcManager: context.read<WebRTCService>(),
              );
              context.read<ActiveChunkRouter>().registerManager(manager);
              return manager;
            }),
        lazy: false,
      ),
    ];
  }

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) {
    return WebMusicScannerService();
  }

  @override
  AbstractFileService createFileService(BuildContext context) {
    return WebFileService();
  }

  @override
  Scaler createScaler(BuildContext context) {
    return WebScaler();
  }
}
