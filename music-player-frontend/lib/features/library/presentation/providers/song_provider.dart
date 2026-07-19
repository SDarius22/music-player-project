import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/chunk_cache_repository.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  static final _logger = Logger('SongProvider');

  final SongService _songService;
  final AbstractMusicScannerService _scannerService;
  final ChunkCacheRepository? _chunkCacheRepository;
  final LocalTrackService? _localTrackService;

  bool _isInitialized = false;
  StreamSubscription<dynamic>? _localTrackSubscription;

  SongProvider(
    this._songService,
    this._scannerService, [
    this._chunkCacheRepository,
    this._localTrackService,
  ]) {
    _localTrackSubscription = _localTrackService?.watchTracks.listen((_) {
      notifyListeners();
    });
    _scannerService.progressStream.listen((progress) {
      _logger.fine('Music scan progress: $progress');
      if ((progress.phase == MusicScanPhase.scanning ||
              progress.phase == MusicScanPhase.enriching) &&
          progress.processed > 0) {
        notifyListeners();
      } else if (progress.phase == MusicScanPhase.completed ||
          progress.phase == MusicScanPhase.cancelled ||
          progress.phase == MusicScanPhase.failed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _localTrackSubscription?.cancel();
    super.dispose();
  }

  @override
  Map<String, dynamic> get sortFields => _songService.sortFields;

  String get defaultSortField => 'Title';

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    // _scannerService.performQuickScan();
    // runSync();

    _isInitialized = true;
  }

  void startBackgroundScan() {
    if (!_isInitialized) return;
    unawaited(_reconcileCacheAvailability());
    unawaited(
      _scannerService.performQuickScan().catchError((Object error) {
        _logger.warning('Background music scan failed', error);
      }),
    );
  }

  Future<void> cancelBackgroundScan() => _scannerService.cancelScan();

  Future<void> _reconcileCacheAvailability() async {
    final cache = _chunkCacheRepository;
    if (cache == null) return;
    try {
      final cachedHashes = (await cache.getCachedFileHashes()).toSet();
      final songs = _songService.getAllLocalSongs();
      final hashesToCheck = <String>{
        ...cachedHashes,
        ...songs
            .where((song) => song.cachedChunkCount > 0 || song.fullyCached)
            .map((song) => song.fileHash),
      };
      for (final hash in hashesToCheck) {
        final song = _songService.getLocalSong(hash);
        if (song == null || !song.hasManifest) continue;
        final indices = await cache.getAvailableChunkIndices(hash);
        final validCount =
            indices
                .where((index) => index < song.expectedChunkCount)
                .toSet()
                .length;
        _songService.updateCacheAvailability(
          hash,
          song.expectedChunkCount,
          validCount,
        );
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to reconcile cached song availability', e);
    }
  }

  Future<Song> enrichSong(Song song) async {
    return await _songService.fullyFetchSong(song);
  }

  @override
  Future<Song?> fetchEntity(BaseEntity song) async {
    if (song is Song && song.fileHash.isEmpty) return song;
    return await _songService.fetchSongByFileHash(song.getHash());
  }

  @override
  Future<PageResult<Song>> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    bool streamOnly = false,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
  }) async {
    return await _songService.getSongsPage(
      query,
      sortField,
      filterAlbumHash,
      filterArtistHash,
      filterPlaylistId,
      ascending,
      localOnly,
      page,
      size,
      streamOnly: streamOnly,
    );
  }

  Future<List<Song>> fetchRecommendedSongs() async {
    return (await _songService.getRecommendations(0, 10)).content;
  }

  Future<List<Song>> fetchRediscoverSongs() async {
    return await _songService.getForgottenFavourites();
  }

  Future<List<Song>> fetchJumpBackSongs() async {
    return await _songService.getQuickDial();
  }

  void removeSong(Song song) {
    _songService.deleteSong(song);
    notifyListeners();
  }

  Future<void> updateSong(Song song) async {
    await _songService.updateSong(song);
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  void refreshSongs() {
    notifyListeners();
  }

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) {
    throw UnimplementedError('getSongsPage is not supported in SongProvider');
  }
}
