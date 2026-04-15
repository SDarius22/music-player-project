import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
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
      return cacheServerArtistDetail(result!);
    } catch (e) {
      _logger.warning('Failed to fetch artist', e);
    }
    return _artistRepository.getArtistByHash(artistHash);
  }

  Future<({List<Artist> content, int totalPages, int page})> getArtistsPage(
    String query,
    String sortField,
    bool ascending,
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
      page * size,
      size,
    );

    final totalPages =
        serverTotalPages ??
        ((_artistRepository.getArtists(query, sortField, ascending).length +
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

  Artist cacheServerArtistDetail(ArtistDetailDto serverArtist) {
    var cachedArtist = _artistRepository.getOrCreateArtist(
      serverArtist.hash,
      serverArtist.name,
    );

    for (var song in serverArtist.songs) {
      var cachedSong = _songRepository.getOrCreateSong(song.fileHash);

      var cachedAlbum = _albumRepository.getOrCreateAlbum(
        song.album.hash,
        song.album.name,
        cachedArtist,
      );

      cachedSong.name = song.name;
      cachedSong.artist.target = cachedArtist;
      cachedSong.album.target = cachedAlbum;
      cachedSong.discNumber = song.discNumber;
      cachedSong.trackNumber = song.trackNumber;
      cachedSong.durationInSeconds = song.durationInSeconds;
      cachedSong.year = song.releaseYear;
      cachedSong.fullyLoaded = true;
      _songRepository.updateSong(cachedSong);

      cachedArtist.addSong(cachedSong);
      cachedAlbum.addSong(cachedSong);
      _albumRepository.updateAlbum(cachedAlbum);
    }

    return _artistRepository.saveArtist(cachedArtist);
  }

  String _toServerSortField(String sortField) {
    return switch (sortField.toLowerCase()) {
      'name' => 'name',
      _ => 'name',
    };
  }
}
