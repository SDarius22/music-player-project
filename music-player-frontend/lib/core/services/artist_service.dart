import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/artists/artist_expanded_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/artist_rest_client.dart';

class ArtistService {
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

  Future<Artist?> fetchArtistDetails(String name) async {
    if (name.isEmpty || name.trim().isEmpty) {
      throw Exception("Artist name cannot be empty.");
    }
    try {
      String artistHash = sha256.convert(utf8.encode(name)).toString();
      final result = await _artistRestService.getArtistByHash(artistHash);
      return cacheServerArtistDetail(result!);
    } catch (e) {
      debugPrint('Failed to fetch artist by server ID $name: $e');
    }
    return _artistRepository.getArtistByName(name);
  }

  Artist getOrCreateArtist(String artistName) {
    return _artistRepository.getOrCreateArtistByName(artistName);
  }

  void updateArtist(Artist artist) {
    _artistRepository.updateArtist(artist);
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

      for (final serverArtist in serverPage.content) {
        cacheServerArtist(serverArtist);
      }
    } catch (e) {
      debugPrint('ArtistService: server fetch failed, using local: $e');
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
    var cachedArtist = _artistRepository.getOrCreateArtistByName(
      serverArtist.name,
    );

    for (var songHash in serverArtist.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(songHash);
      cachedArtist.songs.add(cachedSong);
      cachedSong.artist.targetId = cachedArtist.id;
      _songRepository.updateSong(cachedSong);
    }

    return _artistRepository.saveArtist(cachedArtist);
  }

  Artist cacheServerArtistDetail(ArtistDetailDto serverArtist) {
    var cachedArtist = _artistRepository.getOrCreateArtistByName(
      serverArtist.name,
    );

    for (var song in serverArtist.songs) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(song.fileHash);

      var cachedAlbum = _albumRepository.getOrCreateAlbumByNameAndArtist(
        song.album.name,
        cachedArtist,
      );
      cachedAlbum.artist.targetId = cachedArtist.id;
      cachedAlbum.songs.add(cachedSong);
      _albumRepository.updateAlbum(cachedAlbum);

      cachedSong.artist.targetId = cachedArtist.id;
      cachedSong.album.targetId = cachedAlbum.id;
      cachedSong.name = song.name;
      cachedSong.discNumber = song.discNumber;
      cachedSong.trackNumber = song.trackNumber;
      cachedSong.durationInSeconds = song.durationInSeconds;
      cachedSong.year = song.releaseYear;
      _songRepository.updateSong(cachedSong);

      cachedArtist.songs.add(cachedSong);
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
