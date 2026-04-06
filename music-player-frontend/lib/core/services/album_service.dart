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
    return _albumRepository.getAlbumByNameAndArtist(albumName, artist);
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
    if (serverAlbum.id < 0) {
      throw Exception('Server album must have a valid server ID');
    }

    var cachedAlbum = _albumRepository.getOrCreateAlbumByServerId(
      serverAlbum.id,
    );
    cachedAlbum.name = serverAlbum.name;

    var artist = _artistRepository.getOrCreateArtistByServerId(
      serverAlbum.artist.id,
    );
    artist.name = serverAlbum.artist.name;
    artist.albums.add(cachedAlbum);

    cachedAlbum.artist.targetId = artist.id;

    for (var songHash in serverAlbum.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(songHash);
      cachedAlbum.songs.add(cachedSong);
      artist.songs.add(cachedSong);

      cachedSong.album.targetId = cachedAlbum.id;
      cachedSong.artist.targetId = artist.id;
      _songRepository.updateSong(cachedSong);
    }

    _artistRepository.updateArtist(artist);

    return _albumRepository.saveAlbum(cachedAlbum);
  }

  Album cacheServerAlbumDetail(AlbumDetailDto serverAlbum) {
    if (serverAlbum.id < 0) {
      throw Exception('Server album must have a valid server ID');
    }

    var cachedAlbum = _albumRepository.getOrCreateAlbumByServerId(
      serverAlbum.id,
    );
    cachedAlbum.name = serverAlbum.name;

    var artist = _artistRepository.getOrCreateArtistByServerId(
      serverAlbum.artist.id,
    );
    cachedAlbum.artist.targetId = artist.id;
    artist.albums.add(cachedAlbum);

    for (var song in serverAlbum.songs) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(song.fileHash);
      cachedAlbum.songs.add(cachedSong);
      artist.songs.add(cachedSong);

      cachedSong.artist.targetId = artist.id;
      cachedSong.album.targetId = cachedAlbum.id;
      cachedSong.name = song.name;
      cachedSong.discNumber = song.discNumber;
      cachedSong.trackNumber = song.trackNumber;
      cachedSong.durationInSeconds = song.durationInSeconds;
      cachedSong.year = song.releaseYear;
      _songRepository.updateSong(cachedSong);
    }

    _artistRepository.updateArtist(artist);

    return _albumRepository.saveAlbum(cachedAlbum);
  }

  String _toServerSortField(String sortField) {
    return switch (sortField.toLowerCase()) {
      'name' => 'name',
      _ => 'name',
    };
  }
}
