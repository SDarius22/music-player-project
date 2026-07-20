import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_stat_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/local_track_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/playlist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';

class SessionCleanupService {
  SessionCleanupService({
    required Future<void> Function() resetPlayback,
    required Future<void> Function() stopBackgroundWork,
    required void Function() resetSelection,
    required AlbumRepository albumRepository,
    required ArtistRepository artistRepository,
    required SongRepository songRepository,
    required PlaylistRepository playlistRepository,
    required LocalTrackRepository localTrackRepository,
    required ChunkCacheRepository chunkCacheRepository,
    required ChunkStatRepository chunkStatRepository,
    required SettingsRepository settingsRepository,
  }) : _resetPlayback = resetPlayback,
       _stopBackgroundWork = stopBackgroundWork,
       _resetSelection = resetSelection,
       _albumRepository = albumRepository,
       _artistRepository = artistRepository,
       _songRepository = songRepository,
       _playlistRepository = playlistRepository,
       _localTrackRepository = localTrackRepository,
       _chunkCacheRepository = chunkCacheRepository,
       _chunkStatRepository = chunkStatRepository,
       _settingsRepository = settingsRepository;

  final Future<void> Function() _resetPlayback;
  final Future<void> Function() _stopBackgroundWork;
  final void Function() _resetSelection;
  final AlbumRepository _albumRepository;
  final ArtistRepository _artistRepository;
  final SongRepository _songRepository;
  final PlaylistRepository _playlistRepository;
  final LocalTrackRepository _localTrackRepository;
  final ChunkCacheRepository _chunkCacheRepository;
  final ChunkStatRepository _chunkStatRepository;
  final SettingsRepository _settingsRepository;

  Future<void> clear() async {
    final failures = <Object>[];

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures.add(error);
      }
    }

    await attempt(_stopBackgroundWork);
    await attempt(_resetPlayback);
    await attempt(() async => _resetSelection());
    await attempt(() async => _playlistRepository.clearAll());
    await attempt(() async => _localTrackRepository.clearAll());
    await attempt(() async => _songRepository.clearAll());
    await attempt(() async => _albumRepository.clearAll());
    await attempt(() async => _artistRepository.clearAll());
    await attempt(() async => _chunkStatRepository.clearAll());
    await attempt(() async => _settingsRepository.clearAll());
    await attempt(_chunkCacheRepository.clearAll);

    if (failures.isNotEmpty) {
      throw StateError(
        'Failed to clear ${failures.length} session data source(s)',
      );
    }
  }
}
