import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/lyrics_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/data_sync_rest_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/streaming_rest_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AbstractApp extends StatelessWidget {
  const AbstractApp({super.key});

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9000/api/v1',
  );

  static const String _wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:9000/ws/signaling',
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [..._commonProviders(context), ...extraProviders(context)],
      child: getAppWidget(context),
    );
  }

  List<InheritedProvider> _commonProviders(BuildContext context) {
    return [
      Provider<Scaler>(create: (_) => createScaler(context)),

      ...platformProviders(context),

      Provider<ActiveChunkRouter>(
        create:
            (context) =>
                ActiveChunkRouter(context.read<ChunkCacheRepository>()),
      ),

      Provider<AuthService>(
        create: (context) => AuthService(baseUrl: _apiBaseUrl),
      ),

      Provider<DataSyncService>(
        create:
            (context) => DataSyncService(
              baseUrl: _apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<SongRestService>(
        create:
            (context) => SongRestService(
              baseUrl: _apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<StreamingRestService>(
        create:
            (context) => StreamingRestService(
              baseUrl: _apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<WebRTCService>(
        create: (context) => createWebRTCService(context),
        lazy: false,
      ),

      Provider<AbstractFileService>(
        create: (context) => createFileService(context),
      ),

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
        create:
            (context) => SongService(
              context.read<SongRepository>(),
              context.read<SongRestService>(),
            ),
      ),
      Provider<AbstractMusicScannerService>(
        create: (context) => buildMusicScannerService(context),
      ),

      Provider<AppAudioService>(
        create:
            (context) => AppAudioService(
              context.read<SongService>(),
              context.read<SettingsService>(),
              context.read<PlaylistService>(),
              context.read<AuthService>(),
              (int songId) {
                final manager = ChunkService(
                  songId: songId,
                  cacheRepo: context.read<ChunkCacheRepository>(),
                  streamingClient: context.read<StreamingRestService>(),
                  webrtcManager: context.read<WebRTCService>(),
                );

                context.read<ActiveChunkRouter>().registerManager(manager);

                return manager;
              },
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
        create: (context) => PlaylistProvider(context.read<PlaylistService>()),
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
            context.read<AbstractFileService>(),
          );
          try {
            platform_service.AudioService.init(
              builder: () => audioProvider,
              config: const platform_service.AudioServiceConfig(
                androidNotificationChannelId: 'com.example.musicplayer',
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
              context.read<AbstractFileService>(),
            ),
        lazy: false,
      ),

      ChangeNotifierProvider<UserProvider>(
        create: (context) => UserProvider(context.read<AuthService>()),
      ),
      ChangeNotifierProvider<AbstractAppStateProvider>(
        create: (context) => buildAppStateProvider(context),
      ),
    ];
  }

  List<InheritedProvider> extraProviders(BuildContext context) {
    return [];
  }

  List<InheritedProvider> platformProviders(BuildContext context);

  Widget getAppWidget(BuildContext context);

  Scaler createScaler(BuildContext context);

  AbstractFileService createFileService(BuildContext context);

  AbstractMusicScannerService buildMusicScannerService(BuildContext context);

  AbstractAppStateProvider buildAppStateProvider(BuildContext context);

  WebRTCService createWebRTCService(BuildContext context) {
    final router = context.read<ActiveChunkRouter>();

    final socket = WebSocketChannel.connect(Uri.parse(_wsBaseUrl));

    return WebRTCService(
      myDeviceId: 'linux-client-002',
      authService: context.read<AuthService>(),
      signalingSocket: socket,
      onChunkReceived: router.routeChunk,
      onChunkRequested: router.getLocalChunk,
    );
  }
}
