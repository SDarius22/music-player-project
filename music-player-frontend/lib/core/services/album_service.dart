import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/albums/album_expanded_dto.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

class AlbumService {
  static final _logger = Logger('AlbumService');

  final AlbumRepository _albumRepository;
  final ArtistRepository _artistRepository;
  final SongRepository _songRepository;
  final AlbumRestClient _albumRestService;
  final LocalTrackService? _localTrackService;

  AlbumService(
    this._albumRepository,
    this._artistRepository,
    this._songRepository,
    this._albumRestService, [
    this._localTrackService,
  ]);

  Map<String, dynamic> get sortFields => _albumRepository.sortFields;

  Album getOrCreateAlbum(String albumName, Artist artist) {
    var albumHash =
        sha256
            .convert(utf8.encode('${artist.getName()} - $albumName'))
            .toString();
    return _albumRepository.getOrCreateAlbum(albumHash, albumName, artist);
  }

  void updateAlbum(Album album) {
    _albumRepository.updateAlbum(album);
  }

  Future<Album?> fetchAlbumDetails(String albumHash) async {
    try {
      final serverAlbum = await _albumRestService.getAlbumByHash(albumHash);
      return _cacheServerAlbumSummary(serverAlbum!);
    } catch (e) {
      _logger.warning('AlbumService: server fetch failed, using local', e);
    }
    return _albumRepository.getAlbumByHash(albumHash) ??
        _localAlbums().where((album) => album.hash == albumHash).firstOrNull;
  }

  Future<({List<Album> content, int totalPages, int page})> getAlbumsPage(
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
      if (containLocalOnly && !streamOnly) {
        throw Exception('Forced local only');
      }
      final sort =
          '${_toServerSortField(sortField)},${ascending ? 'asc' : 'desc'}';
      final serverPage = await _albumRestService.getAlbumsPage(
        query: query.isEmpty ? null : query,
        page: page,
        size: size,
        sort: sort,
      );
      serverTotalPages = serverPage.totalPages;
      for (final serverAlbum in serverPage.content) {
        _cacheServerAlbumSummary(serverAlbum);
      }
    } catch (e) {
      _logger.warning('AlbumService: server fetch failed, using local', e);
    }

    final persisted = _albumRepository.getAlbumsPaged(
      query,
      sortField,
      ascending,
      false,
      0,
      1 << 30,
    );
    final localAlbums = _localAlbums();
    final offlineHashes = <String>{};
    final remoteHashes = <String>{};
    for (final song in _songRepository.getAllSongs()) {
      final hash = song.album.target?.hash;
      if (hash == null) continue;
      if (song.isAvailableOffline) offlineHashes.add(hash);
      if (song.isAvailableToStream) remoteHashes.add(hash);
    }
    for (final album in localAlbums) {
      if (album.songs.any((song) => song.isAvailableOffline)) {
        offlineHashes.add(album.hash);
      }
    }

    final byIdentity = <String, Album>{};
    for (final album in [...persisted, ...localAlbums]) {
      if (!album.name.toLowerCase().contains(query.toLowerCase())) continue;
      final identity = PotentialIdentity.create(
        title: album.name,
        artist: album.artist.target?.name ?? 'Unknown Artist',
        durationInSeconds: 0,
      );
      album
        ..hasOfflineSource = offlineHashes.contains(album.hash)
        ..hasRemoteSource =
            !album.hash.startsWith('local-album:') ||
            remoteHashes.contains(album.hash);
      if (album.hasRemoteSource &&
          !album.hash.startsWith('local-album:') &&
          !album.remoteSourceHashes.contains(album.hash)) {
        album.remoteSourceHashes.add(album.hash);
      }
      final existing = byIdentity[identity];
      if (existing == null || (album.isLocal && !existing.isLocal)) {
        if (existing != null) {
          _mergeSources(album, existing);
        }
        byIdentity[identity] = album;
      } else {
        _mergeSources(existing, album);
      }
    }
    final all =
        byIdentity.values
            .where(
              (album) =>
                  (!containLocalOnly || album.isAvailableOffline) &&
                  (!streamOnly || album.isAvailableToStream),
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
            ? <Album>[]
            : all.sublist(offset, (offset + size).clamp(0, all.length));

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((all.length + size - 1) ~/ size).clamp(1, 999999);

    return (content: localContent, totalPages: totalPages, page: page);
  }

  void _mergeSources(Album target, Album source) {
    target
      ..hasOfflineSource |= source.isAvailableOffline
      ..hasRemoteSource |= source.isAvailableToStream;
    for (final hash in source.remoteSourceHashes) {
      if (!target.remoteSourceHashes.contains(hash)) {
        target.remoteSourceHashes.add(hash);
      }
    }
  }

  Album _cacheServerAlbumSummary(AlbumExpandedDto serverAlbum) {
    final artist = _artistRepository.getOrCreateArtist(
      serverAlbum.artist.hash,
      serverAlbum.artist.name,
    );
    final album = _albumRepository.getOrCreateAlbum(
      serverAlbum.hash,
      serverAlbum.name,
      artist,
    );
    album
      ..hasRemoteSource = serverAlbum.songFileHashes.isNotEmpty
      ..remoteSourceHashes = [serverAlbum.hash];
    return _albumRepository.saveAlbum(album);
  }

  Album cacheServerAlbum(AlbumExpandedDto serverAlbum) {
    var cachedArtist = _artistRepository.getOrCreateArtist(
      serverAlbum.artist.hash,
      serverAlbum.artist.name,
    );

    var cachedAlbum = _albumRepository.getOrCreateAlbum(
      serverAlbum.hash,
      serverAlbum.name,
      cachedArtist,
    );
    cachedAlbum
      ..hasRemoteSource = serverAlbum.songFileHashes.isNotEmpty
      ..remoteSourceHashes = [serverAlbum.hash];

    for (var songHash in serverAlbum.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSong(songHash);

      cachedSong.album.targetId = cachedAlbum.id;
      cachedSong.artist.targetId = cachedArtist.id;
      _songRepository.updateSong(cachedSong);

      cachedAlbum.addSong(cachedSong);
      cachedArtist.addSong(cachedSong);
    }

    _artistRepository.updateArtist(cachedArtist);

    return _albumRepository.saveAlbum(cachedAlbum);
  }

  Future<PageResult<Song>> getAlbumSongsPage(
    String albumHash, {
    bool localOnly = false,
    int page = 0,
    int size = 50,
  }) async {
    int? serverTotalPages;
    try {
      if (localOnly) {
        throw Exception('Skipping server fetch due to localOnly=true');
      }
      final serverPage = await _albumRestService.getAlbumSongsPage(
        albumHash: albumHash,
        page: page,
        size: size,
      );
      serverTotalPages = serverPage.totalPages;
      _songRepository.saveSongs(
        serverPage.content.map(_cacheServerSong).toList(growable: false),
      );
    } catch (e) {
      _logger.fine('AlbumService: server fetch failed for album songs: $e');
    }

    final localCandidates = _localSongsForAlbum(albumHash);
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
            for (final song in _songRepository.getAlbumSongsPaged(
              albumHash,
              localOnly,
              offset,
              size,
            ))
              song.getHash(): song,
            for (final song in localSourcePage) song.getHash(): song,
          }.values.take(size).toList()
          ..sort((a, b) => a.trackNumber.compareTo(b.trackNumber));

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_songRepository.getAlbumSongCount(albumHash, localOnly) +
                        localCandidates.length +
                        size -
                        1) ~/
                    size)
                .clamp(1, 999999);

    return PageResult(content: localSongs, totalPages: totalPages, page: page);
  }

  List<Album> _localAlbums() {
    final albums = <String, Album>{};
    for (final track in _localTrackService?.getAll() ?? const []) {
      if (!track.available) continue;
      final song = _localTrackService!.toSongProjection(track);
      final album = song.album.target!;
      final existing = albums[album.hash];
      if (existing == null) {
        albums[album.hash] = album;
      } else {
        existing.addSong(song);
      }
    }
    return albums.values.toList();
  }

  List<Song> _localSongsForAlbum(String albumHash) =>
      _localAlbums()
          .where((album) => album.hash == albumHash)
          .expand((album) => album.getSongs())
          .toList();

  Song _cacheServerSong(SongDto song) {
    var cachedSong = _songRepository.getOrCreateSong(song.fileHash);
    cachedSong.name = song.name;
    cachedSong.durationInSeconds = song.durationInSeconds;
    cachedSong.trackNumber = song.trackNumber;
    cachedSong.discNumber = song.discNumber;
    cachedSong.year = song.releaseYear;
    cachedSong.lastPlayed = song.lastPlayed;
    cachedSong.playCount = song.playCount;
    cachedSong.likedByUser = song.likedByUser;
    cachedSong.fullyLoaded = true;

    var artist = _artistRepository.getOrCreateArtist(
      song.artist.hash,
      song.artist.name,
    );
    cachedSong.artist.target = artist;

    var album = _albumRepository.getOrCreateAlbum(
      song.album.hash,
      song.album.name,
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
