import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/albums/album_detail_dto.dart';
import 'package:music_player_frontend/core/dtos/albums/album_expanded_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/album_rest_client.dart';

class AlbumService {
  final AlbumRepository _albumRepository;
  final ArtistRepository _artistRepository;
  final SongRepository _songRepository;
  final AlbumRestClient _albumRestService;

  AlbumService(
    this._albumRepository,
    this._artistRepository,
    this._songRepository,
    this._albumRestService,
  );

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
      return cacheServerAlbumDetail(serverAlbum!);
    } catch (e) {
      debugPrint('AlbumService: server fetch failed, using local: $e');
    }
    return _albumRepository.getAlbumByHash(albumHash);
  }

  Future<({List<Album> content, int totalPages, int page})> getAlbumsPage(
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
      final serverPage = await _albumRestService.getAlbumsPage(
        query: query.isEmpty ? null : query,
        page: page,
        size: size,
        sort: sort,
      );
      serverTotalPages = serverPage.totalPages;
      for (final serverAlbum in serverPage.content) {
        cacheServerAlbum(serverAlbum);
      }
    } catch (e) {
      debugPrint('AlbumService: server fetch failed, using local: $e');
    }

    final localContent = _albumRepository.getAlbumsPaged(
      query,
      sortField,
      ascending,
      page * size,
      size,
    );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_albumRepository.getAlbums(query, sortField, ascending).length +
                        size -
                        1) ~/
                    size)
                .clamp(1, 999999);

    return (content: localContent, totalPages: totalPages, page: page);
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

  Album cacheServerAlbumDetail(AlbumDetailDto serverAlbum) {
    var cachedArtist = _artistRepository.getOrCreateArtist(
      serverAlbum.artist.hash,
      serverAlbum.artist.name,
    );

    var cachedAlbum = _albumRepository.getOrCreateAlbum(
      serverAlbum.hash,
      serverAlbum.name,
      cachedArtist,
    );

    for (var song in serverAlbum.songs) {
      var cachedSong = _songRepository.getOrCreateSong(song.fileHash);

      cachedSong.artist.targetId = cachedArtist.id;
      cachedSong.album.targetId = cachedAlbum.id;
      cachedSong.setName(song.name);
      cachedSong.discNumber = song.discNumber;
      cachedSong.trackNumber = song.trackNumber;
      cachedSong.durationInSeconds = song.durationInSeconds;
      cachedSong.year = song.releaseYear;
      _songRepository.updateSong(cachedSong);

      cachedArtist.addSong(cachedSong);
      cachedAlbum.addSong(cachedSong);
    }

    _artistRepository.updateArtist(cachedArtist);

    return _albumRepository.saveAlbum(cachedAlbum);
  }

  String _toServerSortField(String sortField) {
    return switch (sortField.toLowerCase()) {
      'name' => 'name',
      _ => 'name',
    };
  }
}
