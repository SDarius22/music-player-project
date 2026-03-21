import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/dtos/artist_page_dto.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/services/rest_clients/artist_rest_service.dart';

class ArtistService {
  final ArtistRepository _artistRepository;
  final ArtistRestService _artistRestService;

  ArtistService(this._artistRepository, this._artistRestService);

  Stream watchArtists() => _artistRepository.watchArtists();

  Map<String, dynamic> get sortFields => _artistRepository.sortFields;

  Artist getArtist(int artistId) {
    try {
      return _artistRepository.getArtist(artistId)!;
    } catch (e) {
      throw Exception("Artist with ID $artistId not found.");
    }
  }

  Artist getOrCreateArtist(String artistName) {
    Artist? existingArtist = _artistRepository.getArtistByName(artistName);
    if (existingArtist != null) {
      return existingArtist;
    }
    Artist newArtist = Artist();
    newArtist.name = artistName;
    return _artistRepository.saveArtist(newArtist);
  }

  Artist getArtistByName(String artistName) {
    try {
      return _artistRepository.getArtistByName(artistName)!;
    } catch (e) {
      throw Exception("Artist with name $artistName not found.");
    }
  }

  List<Artist> getAllArtists() {
    return _artistRepository.getAllArtists();
  }

  void updateArtist(Artist artist) {
    _artistRepository.updateArtist(artist);
  }

  Future<ArtistPageDto> getArtistsPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
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

      if (serverPage.totalElements > 0) {
        final content = _artistRepository.getArtistsPaged(
          query, sortField, ascending, page * size, size,
        );
        return ArtistPageDto(
          content: content,
          page: page,
          size: size,
          totalPages: serverPage.totalPages,
          totalElements: serverPage.totalElements,
        );
      }
    } catch (e) {
      debugPrint('ArtistService: server fetch failed, using local: $e');
    }
    return _localPage(query, sortField, ascending, page, size);
  }

  Artist cacheServerArtist(Artist serverArtist) {
    if (serverArtist.serverId > 0) {
      final byServerId = _artistRepository.getArtistByServerId(
        serverArtist.serverId,
      );
      if (byServerId != null) {
        byServerId.name = serverArtist.name;
        _artistRepository.updateArtist(byServerId);
        return byServerId;
      }
    }

    final byName = _artistRepository.getArtistByName(serverArtist.name);
    if (byName != null) {
      if (byName.serverId <= 0 && serverArtist.serverId > 0) {
        byName.serverId = serverArtist.serverId;
        _artistRepository.updateArtist(byName);
      }
      return byName;
    }

    return _artistRepository.saveArtist(serverArtist);
  }

  ArtistPageDto _localPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) {
    final all = _artistRepository.getArtists(query, sortField, ascending);
    final totalElements = all.length;
    final totalPages = (totalElements / size).ceil();
    final offset = page * size;
    if (offset >= totalElements) {
      return ArtistPageDto(
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
    return ArtistPageDto(
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
