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
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/cover_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/health_rest_client.dart';
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
import 'package:music_player_frontend/core/services/health_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:music_player_frontend/core/ui/screens/welcome_screen.dart';
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
      child: Builder(builder: (innerContext) => getAppWidget(innerContext)),
    );
  }

  Widget responsiveBuilder(Widget? child) {
    return _AuthSessionGuard(
      child: ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 599, name: MOBILE),
          const Breakpoint(start: 600, end: 1024, name: TABLET),
          const Breakpoint(start: 1025, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
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

      ChangeNotifierProvider<AuthService>(
        create: (context) => AuthService(baseUrl: apiBaseUrl),
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
          ChunkStatsService.instance.configure(
            service,
            repository: context.read<ChunkStatRepository>(),
          );
          return service;
        },
        lazy: false,
      ),

      Provider<AbstractFileService>(
        create: (context) => createFileService(context),
      ),
      Provider<LocalTrackService>(
        create:
            (context) => LocalTrackService(
              context.read<LocalTrackRepository>(),
              context.read<SongRepository>(),
            ),
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
      Provider<HealthRestClient>(
        create:
            (context) => HealthRestClient(
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
              context.read<LocalTrackService>(),
            ),
      ),
      Provider<ArtistService>(
        create:
            (context) => ArtistService(
              context.read<ArtistRepository>(),
              context.read<AlbumRepository>(),
              context.read<SongRepository>(),
              context.read<ArtistRestClient>(),
              context.read<LocalTrackService>(),
            ),
      ),
      Provider<SettingsService>(
        create:
            (context) => SettingsService(
              context.read<SettingsRepository>(),
              context.read<PlaybackRestClient>(),
            ),
      ),
      Provider<SongService>(
        create:
            (context) => SongService(
              context.read<SongRepository>(),
              context.read<ArtistRepository>(),
              context.read<AlbumRepository>(),
              context.read<SongRestClient>(),
              context.read<LocalTrackService>(),
            ),
      ),
      Provider<PlaylistService>(
        create:
            (context) => PlaylistService(
              context.read<PlaylistRepository>(),
              context.read<PlaylistRestClient>(),
              context.read<SongRepository>(),
              context.read<SongService>(),
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
              fileService: context.read<AbstractFileService>(),
              coverRestService: context.read<CoverRestClient>(),
              authService: context.read<AuthService>(),
            ),
      ),

      Provider<WebRTCService>(
        create: (context) => createWebRTCService(context),
        lazy: false,
      ),

      Provider<HealthService>(
        create: (context) => HealthService(context.read<HealthRestClient>()),
        lazy: false,
      ),

      Provider<AbstractMusicScannerService>(
        create: (context) => buildMusicScannerService(context),
      ),

      Provider<AppAudioService>(
        create: (context) {
          final chunkServiceCache = <String, ChunkService>{};
          const maxCachedManagers = 9;
          return AppAudioService(
            context.read<SongService>(),
            context.read<SettingsService>(),
            context.read<PlaylistService>(),
            context.read<AuthService>(),
            (String fileHash) {
              final router = context.read<ActiveChunkRouter>();
              final cached = chunkServiceCache[fileHash];
              if (cached != null) {
                chunkServiceCache.remove(fileHash);
                chunkServiceCache[fileHash] = cached;
                router.registerManager(cached);
                return cached;
              }

              final manager = ChunkService(
                fileHash: fileHash,
                cacheRepo: context.read<ChunkCacheRepository>(),
                streamingClient: context.read<StreamingRestClient>(),
                webrtcManager: context.read<WebRTCService>(),
                onCacheAvailabilityChanged:
                    context.read<SongService>().updateCacheAvailability,
                cachedManifestLoader:
                    context.read<SongService>().getCachedManifest,
                onManifestCached: context.read<SongService>().cacheManifest,
                potentialLocalChunkLoader: (hash, manifest, index) {
                  final song = context.read<SongService>().getLocalSong(hash);
                  if (song == null) return Future.value(null);
                  return context
                      .read<LocalTrackService>()
                      .readVerifiedPotentialChunk(song, manifest, index);
                },
              );

              if (chunkServiceCache.length >= maxCachedManagers) {
                final evictedKey = chunkServiceCache.keys.first;
                final evicted = chunkServiceCache.remove(evictedKey);
                if (evicted != null) {
                  router.unregisterManager(evicted);
                  evicted.dispose();
                }
              }
              chunkServiceCache[fileHash] = manager;
              router.registerManager(manager);

              return manager;
            },
            context.read<PlaybackRestClient>(),
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
              context.read<ChunkCacheRepository>(),
              context.read<LocalTrackService>(),
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
                  androidNotificationChannelName: 'MP33r',
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

    return WebRTCService(
      myDeviceId: _deviceId,
      authService: context.read<AuthService>(),
      connectSignaling: () => WebSocketChannel.connect(Uri.parse(wsBaseUrl)),
      settingsService: context.read<SettingsService>(),
      onChunkReceived: router.routeChunk,
      onChunkRequested: router.getLocalChunk,
    );
  }
}

class _AuthSessionGuard extends StatefulWidget {
  const _AuthSessionGuard({required this.child});

  final Widget child;

  @override
  State<_AuthSessionGuard> createState() => _AuthSessionGuardState();
}

class _AuthSessionGuardState extends State<_AuthSessionGuard> {
  AuthStatus? _previousStatus;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<UserProvider>().status;
    if (_previousStatus == AuthStatus.authenticated &&
        status == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<AbstractAppStateProvider>()
            .outerNavigatorKey
            .currentState
            ?.pushAndRemoveUntil(WelcomeScreen.route(), (_) => false);
      });
    }
    _previousStatus = status;
    return widget.child;
  }
}
