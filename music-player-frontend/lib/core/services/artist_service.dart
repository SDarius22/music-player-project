import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

class ArtistService {
  static final _logger = Logger('ArtistService');

  final ArtistRepository _artistRepository;
  final AlbumRepository _albumRepository;
  final SongRepository _songRepository;
  final ArtistRestClient _artistRestService;
  final LocalTrackService? _localTrackService;

  ArtistService(
    this._artistRepository,
    this._albumRepository,
    this._songRepository,
    this._artistRestService, [
    this._localTrackService,
  ]);

  Map<String, dynamic> get sortFields => _artistRepository.sortFields;

  Artist getOrCreateArtist(String artistName) {
    var artistHash = sha256.convert(utf8.encode(artistName)).toString();
    return _artistRepository.getOrCreateArtist(artistHash, artistName);
  }

  void updateArtist(Artist artist) {
    _artistRepository.updateArtist(artist);
  }

  Future<Artist?> fetchArtistDetails(String artistHash) async {
    try {
      final result = await _artistRestService.getArtistByHash(artistHash);
      return _cacheServerArtistSummary(result!);
    } catch (e) {
      _logger.warning('Failed to fetch artist', e);
    }
    return _artistRepository.getArtistByHash(artistHash) ??
        _localArtists()
            .where((artist) => artist.hash == artistHash)
            .firstOrNull;
  }

  Future<({List<Artist> content, int totalPages, int page})> getArtistsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size, {
    bool streamOnly = false,
  }) async {
    int? serverTotalPages;
    try {
      final sort =
          '${_toServerSortField(sortField)},${ascending ? 'asc' : 'desc'}';
      final serverPage = await _artistRestService.getArtistsPage(
        query: query.isEmpty ? null : query,
        page: page,
        size: size,
        sort: sort,
      );
      serverTotalPages = serverPage.totalPages;

      for (final serverArtist in serverPage.content) {
        _cacheServerArtistSummary(serverArtist);
      }
    } catch (e) {
      _logger.warning('ArtistService: server fetch failed, using local', e);
    }

    final persisted = _artistRepository.getArtistsPaged(
      query,
      sortField,
      ascending,
      false,
      0,
      1 << 30,
    );
    final localArtists = _localArtists();
    final offlineHashes = <String>{};
    final remoteHashes = <String>{};
    for (final song in _songRepository.getAllSongs()) {
      final hash = song.artist.target?.hash;
      if (hash == null) continue;
      if (song.isAvailableOffline) offlineHashes.add(hash);
      if (song.isAvailableToStream) remoteHashes.add(hash);
    }
    for (final artist in localArtists) {
      if (artist.songs.any((song) => song.isAvailableOffline)) {
        offlineHashes.add(artist.hash);
      }
    }

    final byIdentity = <String, Artist>{};
    for (final artist in [...persisted, ...localArtists]) {
      if (!artist.name.toLowerCase().contains(query.toLowerCase())) continue;
      final identity = PotentialIdentity.create(
        title: artist.name,
        artist: '',
        durationInSeconds: 0,
      );
      artist
        ..hasOfflineSource = offlineHashes.contains(artist.hash)
        ..hasRemoteSource =
            !artist.hash.startsWith('local-artist:') ||
            remoteHashes.contains(artist.hash);
      if (artist.hasRemoteSource &&
          !artist.hash.startsWith('local-artist:') &&
          !artist.remoteSourceHashes.contains(artist.hash)) {
        artist.remoteSourceHashes.add(artist.hash);
      }
      final existing = byIdentity[identity];
      if (existing == null || (artist.isLocal && !existing.isLocal)) {
        if (existing != null) {
          _mergeSources(artist, existing);
        }
        byIdentity[identity] = artist;
      } else {
        _mergeSources(existing, artist);
      }
    }
    final all =
        byIdentity.values
            .where(
              (artist) =>
                  (!containLocalOnly || artist.isAvailableOffline) &&
                  (!streamOnly || artist.isAvailableToStream),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (!ascending) {
      final reversed = all.reversed.toList();
      all
        ..clear()
        ..addAll(reversed);
    }
    final offset = page * size;
    final localContent =
        offset >= all.length
            ? <Artist>[]
            : all.sublist(offset, (offset + size).clamp(0, all.length));

    final totalPages =
        serverTotalPages ??
        ((all.length + size - 1) ~/ size).clamp(1, double.maxFinite.toInt());

    return (content: localContent, totalPages: totalPages, page: page);
  }

  void _mergeSources(Artist target, Artist source) {
    target
      ..hasOfflineSource |= source.isAvailableOffline
      ..hasRemoteSource |= source.isAvailableToStream;
    for (final hash in source.remoteSourceHashes) {
      if (!target.remoteSourceHashes.contains(hash)) {
        target.remoteSourceHashes.add(hash);
      }
    }
  }

  Artist _cacheServerArtistSummary(ArtistExpandedDto serverArtist) {
    final artist = _artistRepository.getOrCreateArtist(
      serverArtist.hash,
      serverArtist.name,
    );
    artist
      ..hasRemoteSource = serverArtist.songFileHashes.isNotEmpty
      ..remoteSourceHashes = [serverArtist.hash];
    return _artistRepository.saveArtist(artist);
  }

  Artist cacheServerArtist(ArtistExpandedDto serverArtist) {
    var cachedArtist = _artistRepository.getOrCreateArtist(
      serverArtist.hash,
      serverArtist.name,
    );
    cachedArtist
      ..hasRemoteSource = serverArtist.songFileHashes.isNotEmpty
      ..remoteSourceHashes = [serverArtist.hash];

    for (var songHash in serverArtist.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSong(songHash);
      cachedSong.artist.target = cachedArtist;
      _songRepository.updateSong(cachedSong);

      cachedArtist.addSong(cachedSong);
    }

    return _artistRepository.saveArtist(cachedArtist);
  }

  Future<PageResult<Song>> getArtistSongsPage(
    String artistHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async {
    int? serverTotalPages;
    try {
      if (localOnly) {
        throw Exception('Skipping server fetch due to localOnly=true');
      }
      final serverPage = await _artistRestService.getArtistSongsPage(
        artistHash: artistHash,
        page: page,
        size: size,
      );
      serverTotalPages = serverPage.totalPages;
      _songRepository.saveSongs(
        serverPage.content.map(_cacheServerSong).toList(growable: false),
      );
    } catch (e) {
      _logger.fine('ArtistService: server fetch failed for artist songs: $e');
    }

    final localCandidates = _localSongsForArtist(artistHash);
    final offset = page * size;
    final localSourcePage =
        offset >= localCandidates.length
            ? <Song>[]
            : localCandidates.sublist(
              offset,
              (offset + size).clamp(0, localCandidates.length),
            );
    final localSongs =
        <String, Song>{
            for (final song in _songRepository.getArtistSongsPaged(
              artistHash,
              localOnly,
              offset,
              size,
            ))
              song.getHash(): song,
            for (final song in localSourcePage) song.getHash(): song,
          }.values.take(size).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_songRepository.getArtistSongCount(artistHash, localOnly) +
                        localCandidates.length +
                        size -
                        1) ~/
                    size)
                .clamp(1, 999999);

    return PageResult(content: localSongs, totalPages: totalPages, page: page);
  }

  List<Artist> _localArtists() {
    final artists = <String, Artist>{};
    for (final track in _localTrackService?.getAll() ?? const []) {
      if (!track.available) continue;
      final song = _localTrackService!.toSongProjection(track);
      final artist = song.artist.target!;
      final existing = artists[artist.hash];
      if (existing == null) {
        artists[artist.hash] = artist;
      } else {
        existing.addSong(song);
      }
    }
    return artists.values.toList();
  }

  List<Song> _localSongsForArtist(String artistHash) =>
      _localArtists()
          .where((artist) => artist.hash == artistHash)
          .expand((artist) => artist.getSongs())
          .toList();

  Song _cacheServerSong(SongDto serverSong) {
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

  String _toServerSortField(String sortField) {
    return switch (sortField.toLowerCase()) {
      'name' => 'name',
      _ => 'name',
    };
  }
}
