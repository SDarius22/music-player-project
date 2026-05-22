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
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/web_p2p_bridge.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:music_player_frontend/core/ui/abstract_app.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/platforms/web/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/web/services/web_file_service.dart';
import 'package:music_player_frontend/platforms/web/services/web_music_scanner_service.dart';
import 'package:provider/provider.dart';

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
    final appState = context.read<AbstractAppStateProvider>();
    return MaterialApp(
      navigatorKey: appState.outerNavigatorKey,
      builder:
          (context, child) => BotToastInit()(context, responsiveBuilder(child)),
      debugShowCheckedModeBanner: false,
      theme: MusicPlayerTheme.getTheme(),
      home: const LoadingScreen(),
    );
  }

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) {
    return AppStateProvider(
      context.read<AudioProvider>(),
      context.read<HealthService>(),
      context.read<SettingsService>(),
    );
  }

  @override
  List<InheritedProvider> extraProviders(BuildContext context) {
    return [
      Provider<WebP2PBridge>(
        create: (context) {
          final bridge = WebP2PBridge((String fileHash) {
            final manager = ChunkService(
              fileHash: fileHash,
              cacheRepo: context.read<ChunkCacheRepository>(),
              streamingClient: context.read<StreamingRestClient>(),
              webrtcManager: context.read<WebRTCService>(),
            );
            context.read<ActiveChunkRouter>().registerManager(manager);
            return manager;
          });
          context.read<AppAudioService>().setWebSongChangeCallback(
            bridge.notifySong,
          );
          context.read<AppAudioService>().setWebPlaybackReadyCallback(
            bridge.ensureServiceWorkerReady,
          );
          return bridge;
        },
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
}
