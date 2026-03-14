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
import 'package:music_player_frontend/core/repository/objectbox/objectbox_album_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_artist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_settings_repository.dart';
import 'package:music_player_frontend/core/repository/objectbox/objectbox_song_repository.dart';
import 'package:music_player_frontend/core/repository/storage/io_chunk_cache_repo.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/ui/abstract_app.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/providers/app_state_provider.dart';
import 'package:music_player_frontend/platforms/android/services/android_file_service.dart';
import 'package:music_player_frontend/platforms/android/services/android_music_scanner_service.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/loading_screen.dart';
import 'package:provider/provider.dart';

import 'components/android_scaler.dart';

class AndroidApp extends AbstractApp {
  const AndroidApp({super.key});

  @override
  List<InheritedProvider> platformProviders(BuildContext context) {
    return [
      Provider<AlbumRepository>(create: (_) => ObjectBoxAlbumRepository()),
      Provider<ArtistRepository>(create: (_) => ObjectBoxArtistRepository()),
      Provider<PlaylistRepository>(
        create: (_) => ObjectBoxPlaylistRepository(),
      ),
      Provider<SongRepository>(create: (_) => ObjectBoxSongRepository()),
      Provider<ChunkCacheRepository>(create: (_) => IOChunkCacheRepository()),
      Provider<SettingsRepository>(
        create: (_) => ObjectBoxSettingsRepository(),
      ),
    ];
  }

  @override
  AbstractAppStateProvider buildAppStateProvider(BuildContext context) {
    return AppStateProvider(
      context.read<AudioProvider>(),
      context.read<SettingsService>(),
    );
  }

  @override
  AbstractMusicScannerService buildMusicScannerService(BuildContext context) {
    return AndroidMusicScannerService(
      context.read<SongService>(),
      context.read<ArtistService>(),
      context.read<AlbumService>(),
      context.read<AbstractFileService>(),
    );
  }

  @override
  AbstractFileService createFileService(BuildContext context) {
    return AndroidFileService();
  }

  @override
  Scaler createScaler(BuildContext context) {
    return AndroidScaler();
  }

  @override
  Widget getAppWidget(BuildContext context) {
    return MaterialApp(
      builder: BotToastInit(),
      debugShowCheckedModeBanner: false,
      checkerboardOffscreenLayers: true,
      theme: MusicPlayerTheme.getDefaultTheme(),
      home: const SafeArea(child: LoadingScreen()),
    );
  }
}
