import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/album_page_dto.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/album_rest_service.dart';

class AlbumService {
  final AlbumRepository _albumRepository;
  final AlbumRestService _albumRestService;

  AlbumService(this._albumRepository, this._albumRestService);

  Stream watchAlbums() => _albumRepository.watchAlbums();

  Map<String, dynamic> get sortFields => _albumRepository.sortFields;

  Album getAlbum(int albumId) {
    try {
      return _albumRepository.getAlbum(albumId)!;
    } catch (e) {
      throw Exception("Album with ID $albumId not found.");
    }
  }

  Album? getAlbumByServerId(int serverId) {
    return _albumRepository.getAlbumByServerId(serverId);
  }

  Future<Album?> fetchAndCacheAlbumById(int serverId) async {
    final serverAlbum = await _albumRestService.getAlbumById(serverId);
    if (serverAlbum == null) return null;
    return cacheServerAlbum(serverAlbum);
  }

  Album getOrCreateAlbum(String albumName, int artistId, {Uint8List? image}) {
    Album? existingAlbum = _albumRepository.getAlbumByName(albumName);
    if (existingAlbum != null) {
      existingAlbum.imageBytes ??= image;
      _albumRepository.saveAlbum(existingAlbum);
      return existingAlbum;
    }
    Album newAlbum = Album();
    newAlbum.name = albumName;
    newAlbum.imageBytes = image;
    newAlbum.artist.targetId = artistId;
    return _albumRepository.saveAlbum(newAlbum);
  }

  List<Album> getAllAlbums() {
    return _albumRepository.getAllAlbums();
  }

  void updateAlbum(Album album) {
    _albumRepository.updateAlbum(album);
  }

  Future<AlbumPageDto> getAlbumsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    try {
      final sort =
          '${_toServerSortField(sortField)},${ascending ? 'asc' : 'desc'}';
      final serverPage = await _albumRestService.getAlbumsPage(
        query: query.isEmpty ? null : query,
        page: page,
        size: size,
        sort: sort,
      );

      for (final serverAlbum in serverPage.content) {
        cacheServerAlbum(serverAlbum);
      }

      if (serverPage.totalElements > 0) {
        final content = _albumRepository.getAlbumsPaged(
          query,
          sortField,
          ascending,
          page * size,
          size,
        );
        return AlbumPageDto(
          content: content,
          page: page,
          size: size,
          totalPages: serverPage.totalPages,
          totalElements: serverPage.totalElements,
        );
      }
    } catch (e) {
      debugPrint('AlbumService: server fetch failed, using local: $e');
    }
    return _localPage(query, sortField, ascending, page, size);
  }

  Album cacheServerAlbum(Album serverAlbum) {
    if (serverAlbum.serverId > 0) {
      final byServerId = _albumRepository.getAlbumByServerId(
        serverAlbum.serverId,
      );
      if (byServerId != null) {
        byServerId.name = serverAlbum.name;
        if (byServerId.imageBytes == null && serverAlbum.imageBytes != null) {
          byServerId.imageBytes = serverAlbum.imageBytes;
        }
        _albumRepository.updateAlbum(byServerId);
        return byServerId;
      }
    }

    final artistName = serverAlbum.artist.target?.name;
    Album? byName;
    if (artistName != null && artistName.isNotEmpty) {
      byName = _albumRepository.getAlbumByNameAndArtistName(
        serverAlbum.name,
        artistName,
      );
    }
    byName ??= _albumRepository.getAlbumByName(serverAlbum.name);
    if (byName != null) {
      if (byName.serverId <= 0 && serverAlbum.serverId > 0) {
        byName.serverId = serverAlbum.serverId;
      }
      if (byName.imageBytes == null && serverAlbum.imageBytes != null) {
        byName.imageBytes = serverAlbum.imageBytes;
      }
      _albumRepository.updateAlbum(byName);
      return byName;
    }

    if (serverAlbum.artist.target != null &&
        serverAlbum.artist.target!.id == 0) {
      serverAlbum.artist.target = null;
    }
    return _albumRepository.saveAlbum(serverAlbum);
  }

  AlbumPageDto _localPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) {
    final all = _albumRepository.getAlbums(query, sortField, ascending);
    final totalElements = all.length;
    final totalPages = (totalElements / size).ceil();
    final offset = page * size;
    if (offset >= totalElements) {
      return AlbumPageDto(
        content: const [],
        page: page,
        size: size,
        totalPages: totalPages,
        totalElements: totalElements,
      );
    }
    final content = all.sublist(
      offset,
      (offset + size).clamp(0, totalElements),
    );
    return AlbumPageDto(
      content: content,
      page: page,
      size: size,
      totalPages: totalPages,
      totalElements: totalElements,
    );
  }

  String _toServerSortField(String sortField) {
    return switch (sortField.toLowerCase()) {
      'name' => 'name',
      _ => 'name',
    };
  }
}
