import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/dtos/chunk_manifest_dto.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/playback_source_selection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';

class SongService {
  static final _logger = Logger('SongService');

  final SongRepository _songRepository;
  final ArtistRepository _artistRepository;
  final AlbumRepository _albumRepository;
  final SongRestClient _songRestService;
  final LocalTrackService? _localTrackService;

  SongService(
    this._songRepository,
    this._artistRepository,
    this._albumRepository,
    this._songRestService, [
    this._localTrackService,
  ]);

  Map<String, dynamic> get sortFields => _songRepository.sortFields;

  Stream<dynamic> get watchSongs => _songRepository.watchSongs();

  Stream<dynamic>? get watchLocalTracks => _localTrackService?.watchTracks;

  Song? getLocalSong(String songHash) {
    if (songHash.isEmpty) {
      throw ArgumentError('Song hash cannot be empty');
    }

    try {
      return _songRepository.getSongByFileHash(songHash);
    } catch (_) {
      return null;
    }
  }

  Song? getLocalSongByPath(String path) {
    if (path.isEmpty) return null;
    return _songRepository.getSongByLocalPath(path);
  }

  Song getOrCreateSong(String fileHash) {
    if (fileHash.isEmpty) {
      throw ArgumentError('File hash cannot be empty');
    }
    return _songRepository.getOrCreateSong(fileHash);
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    final local = _songRepository.getSongByFileHash(fileHash);
    if (local != null) return local;
    try {
      final serverSong = await _songRestService.getServerSong(fileHash);
      cacheServerSongs([serverSong]);
      return _songRepository.getSongByFileHash(fileHash);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch song $fileHash from server: $e',
      );
      return null;
    }
  }

  Future<List<Song>> fullyFetchSongs(List<Song> songs) async {
    List<Song> fullyFetched = [];
    for (var song in songs) {
      fullyFetched.add(await fullyFetchSong(song));
    }
    return fullyFetched;
  }

  Future<Song> fullyFetchSong(Song song) async {
    if (song.fileHash.isEmpty) return song;
    if (song.fullyLoaded) return song;
    var localSong = _songRepository.getSongByFileHash(song.getHash());
    if (localSong != null && localSong.fullyLoaded) return localSong;

    _logger.fine('Fully fetching song ${song.getHash()} from server...');
    try {
      final serverSong = await _songRestService.getServerSong(song.getHash());
      final fetched = _cacheServerSong(serverSong);
      return fetched.getHash() == song.getHash() ? fetched : song;
    } catch (e) {
      _logger.fine(
        'SongService: failed to fully fetch song ${song.getHash()} from server: $e',
      );
      return song;
    }
  }

  PlaybackSourceSelection resolvePlaybackSource(Song song) {
    final localService = _localTrackService;
    if (song.localSourceKey != null && localService != null) {
      final managed = localService.getBySourceKey(song.localSourceKey!);
      if (managed != null) {
        if (!managed.available ||
            (song.fileHash.isNotEmpty &&
                managed.contentHash != song.fileHash)) {
          return const PlaybackSourceSelection(
            kind: PlaybackSourceKind.unavailable,
            strength: SourceMatchStrength.none,
            reason: 'managed local source is unavailable or stale',
          );
        }
        return _localSelection(
          managed,
          SourceMatchStrength.exactSource,
          'exact managed local source',
        );
      }
      return const PlaybackSourceSelection(
        kind: PlaybackSourceKind.unavailable,
        strength: SourceMatchStrength.none,
        reason: 'managed local source was removed',
      );
    }
    if (song.hasLocalFile &&
        (song.localSourceKey == null ||
            localService?.getBySourceKey(song.localSourceKey!) == null)) {
      return PlaybackSourceSelection(
        kind: PlaybackSourceKind.local,
        strength: SourceMatchStrength.exactSource,
        sourceKey: song.localSourceKey,
        sourceUri: song.path,
        reason: 'unmanaged imported local source',
      );
    }

    final available =
        (localService?.getAll() ?? const <LocalTrack>[])
            .where((track) => track.available)
            .toList();
    LocalTrack? exact;
    if (song.fileHash.isNotEmpty) {
      final matches =
          available
              .where((track) => track.contentHash == song.fileHash)
              .toList();
      // Byte-identical replicas are not ambiguous recordings.
      if (matches.isNotEmpty) exact = matches.first;
    }
    if (exact != null) {
      return _localSelection(
        exact,
        song.localSourceKey == exact.sourceKey
            ? SourceMatchStrength.exactSource
            : SourceMatchStrength.exactContent,
        'exact persisted local identity',
      );
    }

    final title = _normalize(song.name);
    final artist = _normalize(song.artist.target?.name ?? '');
    final album = _normalize(song.album.target?.name ?? '');
    final metadataMatches =
        available.where((track) {
          if (_isPlaceholder(title) ||
              _isPlaceholder(artist) ||
              _normalize(track.name) != title ||
              _normalize(track.artistName) != artist) {
            return false;
          }
          if (!_durationMatches(
            song.durationInSeconds,
            track.durationInSeconds,
          )) {
            return false;
          }
          final localAlbum = _normalize(track.albumName);
          return _isPlaceholder(album) ||
              _isPlaceholder(localAlbum) ||
              album == localAlbum;
        }).toList();

    if (metadataMatches.length > 1) {
      return PlaybackSourceSelection(
        kind: PlaybackSourceKind.ambiguous,
        strength: SourceMatchStrength.none,
        reason: 'multiple conservative metadata candidates',
        candidateCount: metadataMatches.length,
      );
    }
    if (metadataMatches.length == 1) {
      return _localSelection(
        metadataMatches.single,
        SourceMatchStrength.metadata,
        'single conservative metadata candidate',
      );
    }
    return const PlaybackSourceSelection(
      kind: PlaybackSourceKind.unavailable,
      strength: SourceMatchStrength.none,
      reason: 'no eligible local source',
    );
  }

  PlaybackSourceSelection _localSelection(
    LocalTrack track,
    SourceMatchStrength strength,
    String reason,
  ) {
    return PlaybackSourceSelection(
      kind: PlaybackSourceKind.local,
      strength: strength,
      sourceKey: track.sourceKey,
      sourceUri: track.sourceUri,
      reason: reason,
    );
  }

  bool _durationMatches(int expected, int actual) {
    if (expected <= 0 || actual <= 0) return false;
    final tolerance = (expected * 0.01).round().clamp(2, 5);
    return (expected - actual).abs() <= tolerance;
  }

  String _normalize(String value) =>
      value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  bool _isPlaceholder(String value) =>
      value.isEmpty ||
      const {
        'unknown',
        'unknown song',
        'unknown artist',
        'unknown album',
      }.contains(value);

  Future<void> updateSong(Song song) async {
    if (song.fileHash.isEmpty) {
      _localTrackService?.updateFromProjection(song);
      return;
    }
    try {
      await _songRestService.updateSongLibraryEntry(
        song.fileHash,
        song.likedByUser,
        song.lastPlayed,
        song.playCount,
      );
    } catch (e) {
      _logger.fine(
        'SongService: failed to update song lib entry ${song.getHash()} on server: $e',
      );
    }
    _songRepository.updateSong(song);
  }

  void updateSongsBatch(List<Song> songs) {
    _songRepository.updateSongs(songs);
  }

  void updateCacheAvailability(
    String fileHash,
    int expectedChunks,
    int cachedChunks,
  ) {
    final song = _songRepository.getSongByFileHash(fileHash);
    if (song == null) return;
    song.cachedChunkCount = cachedChunks.clamp(0, expectedChunks);
    song.fullyCached =
        expectedChunks > 0 && song.cachedChunkCount >= expectedChunks;
    _songRepository.updateSong(song);
  }

  ChunkManifestDto? getCachedManifest(String fileHash) {
    final song = _songRepository.getSongByFileHash(fileHash);
    if (song == null || !song.hasManifest) return null;

    final manifest = ChunkManifestDto.fromJson({
      'fileHash': song.fileHash,
      'totalChunks': song.chunkHashes.length,
      'chunkSize': song.manifestChunkSize,
      'totalBytes': song.manifestTotalBytes,
      'hashes': song.chunkHashes,
    });
    return manifest.isValidFor(fileHash) ? manifest : null;
  }

  void cacheManifest(ChunkManifestDto manifest) {
    if (!manifest.isValidFor(manifest.fileHash)) {
      throw FormatException('Invalid chunk manifest for ${manifest.fileHash}');
    }
    final song = _songRepository.getOrCreateSong(manifest.fileHash);
    song.manifestChunkSize = manifest.chunkSize;
    song.manifestTotalBytes = manifest.totalBytes;
    song.chunkHashes = List<String>.from(manifest.hashes);
    if (song.cachedChunkCount > song.expectedChunkCount) {
      song.cachedChunkCount = song.expectedChunkCount;
    }
    song.fullyCached =
        song.expectedChunkCount > 0 &&
        song.cachedChunkCount >= song.expectedChunkCount;
    _songRepository.updateSong(song);
  }

  void deleteSong(Song song) {
    _songRepository.deleteSong(song);
  }

  List<Song> getAllLocalSongs() => _songRepository.getAllSongs();

  List<Song> getAllLocalCandidates() {
    final service = _localTrackService;
    return <Song>[
      ..._songRepository.getAllSongs(),
      if (service != null) ...service.getAll().map(service.toSongProjection),
    ];
  }

  void reconcileMissingLocalFiles(Set<String> discoveredPaths) {
    final missing =
        _songRepository
            .getAllSongs()
            .where(
              (song) =>
                  song.hasLocalFile &&
                  song.localFileSize != null &&
                  !discoveredPaths.contains(song.path),
            )
            .toList();
    for (final song in missing) {
      song
        ..path = null
        ..localFileSize = null
        ..localFileModifiedAt = null;
    }
    if (missing.isNotEmpty) _songRepository.updateSongs(missing);
  }

  Future<PageResult<Song>> getSongsPage(
    String query,
    String sortField,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
    bool ascending,
    bool localOnly,
    int page,
    int pageSize, {
    bool streamOnly = false,
  }) async {
    int? serverTotalPages;
    try {
      if (localOnly && !streamOnly) {
        throw Exception('Skipping server fetch due to localOnly=true');
      }
      final serverPage = await _songRestService.getSongsPage(
        query: query,
        filterAlbumHash: filterAlbumHash,
        filterArtistHash: filterArtistHash,
        filterPlaylistId: filterPlaylistId,
        page: page,
        size: pageSize,
        sort: _toServerSort(sortField, ascending),
      );
      serverTotalPages = serverPage.totalPages;
      cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine('SongService: server fetch failed for getSongsPage: $e');
    }
    final localSongs = _buildUnifiedLibrary(query, localOnly, streamOnly);
    _sortSongs(localSongs, sortField, ascending);
    final offset = page * pageSize;
    final pageSongs =
        offset >= localSongs.length
            ? <Song>[]
            : localSongs.sublist(
              offset,
              (offset + pageSize).clamp(0, localSongs.length),
            );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((localSongs.length + pageSize - 1) ~/ pageSize).clamp(1, 999999);

    return PageResult(content: pageSongs, totalPages: totalPages, page: page);
  }

  List<Song> _buildUnifiedLibrary(
    String query,
    bool localOnly,
    bool streamOnly,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final candidates = <Song>[
      ..._songRepository.getAllSongs().where(
        (song) =>
            song.fullyLoaded &&
            song.name.toLowerCase().contains(normalizedQuery),
      ),
      ...?_localTrackService
          ?.getAll()
          .where(
            (track) =>
                track.available &&
                track.name.toLowerCase().contains(normalizedQuery),
          )
          .map(_localTrackService.toSongProjection),
    ];

    final identities = Map<Song, String>.identity();
    final identityCounts = <String, List<Song>>{};
    for (final candidate in candidates) {
      final identity =
          '${_normalize(candidate.name)}\u0000${_normalize(candidate.artist.target?.name ?? '')}';
      identities[candidate] = identity;
      identityCounts.putIfAbsent(identity, () => []).add(candidate);
    }

    final grouped = <String, Song>{};
    for (final candidate in candidates) {
      final identity = identities[candidate]!;
      final groupMembers = identityCounts[identity]!;
      final localCount = groupMembers.where((song) => song.hasLocalFile).length;
      final remoteCount = groupMembers.length - localCount;
      final firstAlbum = _normalize(
        groupMembers.first.album.target?.name ?? '',
      );
      final lastAlbum = _normalize(groupMembers.last.album.target?.name ?? '');
      final uniqueConservativePair =
          localCount == 1 &&
          remoteCount == 1 &&
          !_isPlaceholder(_normalize(candidate.name)) &&
          !_isPlaceholder(_normalize(candidate.artist.target?.name ?? '')) &&
          _durationMatches(
            groupMembers.first.durationInSeconds,
            groupMembers.last.durationInSeconds,
          ) &&
          (_isPlaceholder(firstAlbum) ||
              _isPlaceholder(lastAlbum) ||
              firstAlbum == lastAlbum);
      final groupKey =
          uniqueConservativePair
              ? identity
              : '$identity:${candidate.getHash()}';
      final current = grouped[groupKey];
      if (current == null) {
        candidate.localSourceUris = [
          if (candidate.hasLocalFile) candidate.path!,
        ];
        grouped[groupKey] = candidate;
        continue;
      }

      if (!candidate.hasLocalFile &&
          candidate.fileHash.isNotEmpty &&
          !current.potentialRemoteHashes.contains(candidate.fileHash)) {
        current.potentialRemoteHashes.add(candidate.fileHash);
      }
      if (!current.hasLocalFile &&
          current.fileHash.isNotEmpty &&
          !candidate.potentialRemoteHashes.contains(current.fileHash)) {
        candidate.potentialRemoteHashes.add(current.fileHash);
      }
      if (candidate.hasLocalFile &&
          !current.localSourceUris.contains(candidate.path)) {
        current.localSourceUris.add(candidate.path!);
      }

      // A directly playable local source is the default representation.
      if (!current.hasLocalFile && candidate.hasLocalFile) {
        candidate.potentialRemoteHashes =
            <String>{
              ...current.potentialRemoteHashes,
              if (current.fileHash.isNotEmpty) current.fileHash,
            }.toList();
        candidate.localSourceUris =
            <String>{...current.localSourceUris, candidate.path!}.toList();
        grouped[groupKey] = candidate;
      }
    }
    return grouped.values
        .where(
          (song) =>
              (!localOnly || song.isAvailableOffline) &&
              (!streamOnly || song.isAvailableToStream),
        )
        .toList();
  }

  void _sortSongs(List<Song> songs, String sortField, bool ascending) {
    int compare(Song a, Song b) {
      final result = switch (sortField) {
        'Duration' => a.durationInSeconds.compareTo(b.durationInSeconds),
        'Year' => a.year.compareTo(b.year),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return ascending ? result : -result;
    }

    songs.sort(compare);
  }

  Future<PageResult<Song>> getRecommendations(int page, int size) async {
    final serverPage = await _songRestService.getRecommendations(
      page: page,
      size: size,
    );
    var serverTotalPages = serverPage.totalPages;
    var recommendations = cacheServerSongs(serverPage.content);
    return PageResult(
      content: recommendations,
      totalPages: serverTotalPages,
      page: page,
    );
  }

  Future<List<Song>> getForgottenFavourites() async {
    final page = await _songRestService.getForgottenFavourites();
    return cacheServerSongs(page.content);
  }

  Future<List<Song>> getQuickDial() async {
    final page = await _songRestService.getQuickDial();
    return cacheServerSongs(page.content);
  }

  Future<List<Song>> getFavoriteSongs() async {
    final local = _songRepository.getFavoriteSongs();
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getFavourites();
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch favorite songs from server: $e',
      );
      return [];
    }
  }

  Future<List<Song>> getMostPlayedSongs(int limit) async {
    final local = _songRepository.getMostPlayedSongs(limit);
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getMostPlayed(size: limit);
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine('SongService: failed to fetch most played from server: $e');
      return [];
    }
  }

  Future<List<Song>> getRecentlyPlayedSongs(int limit) async {
    final local = _songRepository.getRecentlyPlayedSongs(limit);
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getRecentlyPlayed(size: limit);
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch recently played from server: $e',
      );
      return [];
    }
  }

  List<Song> cacheServerSongs(List<SongDto> serverSongs) {
    List<Song> cached = [];
    for (var serverSong in serverSongs) {
      cached.add(_cacheServerSong(serverSong));
    }
    return cached;
  }

  Song _cacheServerSong(SongDto serverSong) {
    if (serverSong.fileHash.isEmpty) {
      throw Exception('Server song must have a file hash');
    }

    var cachedSong = _songRepository.getOrCreateSong(serverSong.fileHash);
    cachedSong.name = serverSong.name;
    cachedSong.durationInSeconds = serverSong.durationInSeconds;
    cachedSong.trackNumber = serverSong.trackNumber;
    cachedSong.discNumber = serverSong.discNumber;
    cachedSong.year = serverSong.releaseYear;
    cachedSong.lastPlayed = serverSong.lastPlayed;
    cachedSong.playCount = serverSong.playCount;
    cachedSong.likedByUser = serverSong.likedByUser;
    cachedSong.fullyLoaded = true;

    var artist = _artistRepository.getOrCreateArtist(
      serverSong.artist.hash,
      serverSong.artist.name,
    );
    cachedSong.artist.target = artist;

    var album = _albumRepository.getOrCreateAlbum(
      serverSong.album.hash,
      serverSong.album.name,
      artist,
    );
    cachedSong.album.target = album;

    var finalSong = _songRepository.saveSong(cachedSong);

    artist.addSong(finalSong);
    _artistRepository.updateArtist(artist);

    album.addSong(finalSong);
    _albumRepository.updateAlbum(album);

    return finalSong;
  }

  String _toServerSort(String sortField, bool ascending) {
    final normalized = sortField.trim().toLowerCase();

    final serverField = switch (normalized) {
      'title' || 'name' => 'name',
      'year' => 'year',
      'duration' || 'durationinseconds' => 'durationInSeconds',
      'track' || 'tracknumber' => 'trackNumber',
      'disc' || 'discnumber' => 'discNumber',
      _ => 'name',
    };

    return '$serverField,${ascending ? 'asc' : 'desc'}';
  }
}
