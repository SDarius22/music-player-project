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

class ArtistService {
  static final _logger = Logger('ArtistService');

  final ArtistRepository _artistRepository;
  final AlbumRepository _albumRepository;
  final SongRepository _songRepository;
  final ArtistRestClient _artistRestService;

  ArtistService(
    this._artistRepository,
    this._albumRepository,
    this._songRepository,
    this._artistRestService,
  );

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
      return cacheServerArtist(result!);
    } catch (e) {
      _logger.warning('Failed to fetch artist', e);
    }
    return _artistRepository.getArtistByHash(artistHash);
  }

  Future<({List<Artist> content, int totalPages, int page})> getArtistsPage(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int page,
    int size,
  ) async {
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
        cacheServerArtist(serverArtist);
      }
    } catch (e) {
      _logger.warning('ArtistService: server fetch failed, using local', e);
    }

    final localContent = _artistRepository.getArtistsPaged(
      query,
      sortField,
      ascending,
      containLocalOnly,
      page * size,
      size,
    );

    final totalPages =
        serverTotalPages ??
        ((_artistRepository.getArtistCount(query, containLocalOnly) +
                    size -
                    1) ~/
                size)
            .clamp(1, double.maxFinite.toInt());

    return (content: localContent, totalPages: totalPages, page: page);
  }

  Artist cacheServerArtist(ArtistExpandedDto serverArtist) {
    var cachedArtist = _artistRepository.getOrCreateArtist(
      serverArtist.hash,
      serverArtist.name,
    );

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

    final localSongs = _songRepository.getArtistSongsPaged(
      artistHash,
      localOnly,
      page * size,
      size,
    );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_songRepository.getArtistSongCount(artistHash, localOnly) +
                        size -
                        1) ~/
                    size)
                .clamp(1, 999999);

    return PageResult(content: localSongs, totalPages: totalPages, page: page);
  }

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
