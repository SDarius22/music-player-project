import 'dart:async';
import 'dart:math';

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
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/cover_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/data_sync_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/lyrics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AbstractApp extends StatelessWidget {
  const AbstractApp({super.key});

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9000/api/v1',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:9000/ws/signaling',
  );

  static final String _deviceId = _generateDeviceId();

  static String _generateDeviceId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [..._commonProviders(context), ...extraProviders(context)],
      child: getAppWidget(context),
    );
  }

  Widget responsiveBuilder(Widget? child) {
    return ResponsiveBreakpoints.builder(
      child: child!,
      breakpoints: [
        const Breakpoint(start: 0, end: 599, name: MOBILE),
        const Breakpoint(start: 600, end: 1024, name: TABLET),
        const Breakpoint(start: 1025, end: 1920, name: DESKTOP),
        const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
      ],
    );
  }

  List<InheritedProvider> _commonProviders(BuildContext context) {
    return [
      ...platformProviders(context),

      Provider<ActiveChunkRouter>(
        create:
            (context) =>
                ActiveChunkRouter(context.read<ChunkCacheRepository>()),
      ),

      Provider<AuthService>(
        create: (context) => AuthService(baseUrl: apiBaseUrl),
      ),

      Provider<DataSyncClient>(
        create:
            (context) => DataSyncClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<SongRestClient>(
        create:
            (context) => SongRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<StreamingRestClient>(
        create:
            (context) => StreamingRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<StatisticsRestClient>(
        create: (context) {
          final service = StatisticsRestClient(
            baseUrl: apiBaseUrl,
            authService: context.read<AuthService>(),
          );
          ChunkStatsService.instance.configure(service);
          return service;
        },
        lazy: false,
      ),

      Provider<AbstractFileService>(
        create: (context) => createFileService(context),
      ),

      Provider<CoverRestClient>(
        create:
            (context) => CoverRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),
      Provider<AlbumRestClient>(
        create:
            (context) => AlbumRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),
      Provider<ArtistRestClient>(
        create:
            (context) => ArtistRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),
      Provider<LyricsRestClient>(create: (context) => LyricsRestClient()),
      Provider<PlaylistRestClient>(
        create:
            (context) => PlaylistRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),
      Provider<PlaybackRestClient>(
        create:
            (context) => PlaybackRestClient(
              baseUrl: apiBaseUrl,
              authService: context.read<AuthService>(),
            ),
      ),
      Provider<AlbumService>(
        create:
            (context) => AlbumService(
              context.read<AlbumRepository>(),
              context.read<ArtistRepository>(),
              context.read<SongRepository>(),
              context.read<AlbumRestClient>(),
            ),
      ),
      Provider<ArtistService>(
        create:
            (context) => ArtistService(
              context.read<ArtistRepository>(),
              context.read<AlbumRepository>(),
              context.read<SongRepository>(),
              context.read<ArtistRestClient>(),
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
              context.read<ArtistRepository>(),
              context.read<AlbumRepository>(),
              context.read<SongRestClient>(),
              context.read<DataSyncClient>(),
            ),
      ),
      Provider<PlaylistService>(
        create:
            (context) => PlaylistService(
              context.read<PlaylistRepository>(),
              context.read<SongRepository>(),
              context.read<PlaylistRestClient>(),
            ),
      ),
      Provider<LyricsService>(
        create:
            (context) => LyricsService(
              context.read<AbstractFileService>(),
              context.read<LyricsRestClient>(),
            ),
      ),

      Provider<CoverService>(
        create:
            (context) => CoverService(
              albumService: context.read<AlbumService>(),
              songService: context.read<SongService>(),
              artistService: context.read<ArtistService>(),
              playlistService: context.read<PlaylistService>(),
              coverRestService: context.read<CoverRestClient>(),
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<WebRTCService>(
        create: (context) => createWebRTCService(context),
        lazy: false,
      ),
      Provider<AbstractMusicScannerService>(
        create: (context) => buildMusicScannerService(context),
      ),

      Provider<AppAudioService>(
        create: (context) {
          final chunkServiceCache = <String, ChunkService>{};
          return AppAudioService(
            context.read<SongService>(),
            context.read<SettingsService>(),
            context.read<PlaylistService>(),
            context.read<AuthService>(),
            (String fileHash) {
              final cached = chunkServiceCache[fileHash];
              if (cached != null) return cached;

              final manager = ChunkService(
                fileHash: fileHash,
                cacheRepo: context.read<ChunkCacheRepository>(),
                streamingClient: context.read<StreamingRestClient>(),
                webrtcManager: context.read<WebRTCService>(),
              );

              if (chunkServiceCache.length >= 5) {
                chunkServiceCache.remove(chunkServiceCache.keys.first);
              }
              chunkServiceCache[fileHash] = manager;
              context.read<ActiveChunkRouter>().registerManager(manager);

              return manager;
            },
            playbackRestService: context.read<PlaybackRestClient>(),
          );
        },
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
          unawaited(() async {
            try {
              await platform_service.AudioService.init(
                builder: () => audioProvider,
                config: const platform_service.AudioServiceConfig(
                  androidNotificationChannelId: 'com.example.musicplayer',
                  androidNotificationChannelName: 'Music Player',
                  androidStopForegroundOnPause: false,
                ),
              );
            } catch (e) {
              debugPrint('AudioService.init error: $e');
            }
          }());
          return audioProvider;
        },
      ),
      ChangeNotifierProvider<LyricsProvider>(
        create:
            (context) => LyricsProvider(
              context.read<LyricsService>(),
              context.read<AppAudioService>(),
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

  AbstractFileService createFileService(BuildContext context);

  AbstractMusicScannerService buildMusicScannerService(BuildContext context);

  AbstractAppStateProvider buildAppStateProvider(BuildContext context);

  WebRTCService createWebRTCService(BuildContext context) {
    final router = context.read<ActiveChunkRouter>();
    final socket = WebSocketChannel.connect(Uri.parse(wsBaseUrl));

    return WebRTCService(
      myDeviceId: _deviceId,
      authService: context.read<AuthService>(),
      signalingSocket: socket,
      settingsService: context.read<SettingsService>(),
      onChunkReceived: router.routeChunk,
      onChunkRequested: router.getLocalChunk,
      onSyncTrigger: context.read<SongService>().runSync,
    );
  }
}
