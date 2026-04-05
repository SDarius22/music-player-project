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

  Stream watchArtists() => _artistRepository.watchArtists();

  Map<String, dynamic> get sortFields => _artistRepository.sortFields;

  Artist getArtist(int artistId) {
    try {
      return _artistRepository.getArtist(artistId)!;
    } catch (e) {
      throw Exception("Artist with ID $artistId not found.");
    }
  }

  Future<Artist> getArtistByServerId(int serverId) async {
    try {
      final result = await _artistRestService.getArtistById(serverId);
      return cacheServerArtistDetail(result!);
    } catch (e) {
      debugPrint('Failed to fetch artist by server ID $serverId: $e');
    }
    return _artistRepository.getArtistByServerId(serverId)!;
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
    if (serverArtist.id <= 0) {
      throw Exception('Server artist must have a valid ID');
    }

    var cachedArtist = _artistRepository.getOrCreateArtistByServerId(
      serverArtist.id,
    );
    cachedArtist.name = serverArtist.name;

    for (var songHash in serverArtist.songFileHashes) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(songHash);
      cachedArtist.songs.add(cachedSong);
      cachedSong.artist.targetId = cachedArtist.id;
      _songRepository.updateSong(cachedSong);
    }

    return _artistRepository.saveArtist(cachedArtist);
  }

  Artist cacheServerArtistDetail(ArtistDetailDto serverArtist) {
    if (serverArtist.id <= 0) {
      throw Exception('Server artist must have a valid ID');
    }

    var cachedArtist = _artistRepository.getOrCreateArtistByServerId(
      serverArtist.id,
    );
    cachedArtist.name = serverArtist.name;

    for (var song in serverArtist.songs) {
      var cachedSong = _songRepository.getOrCreateSongByFileHash(song.fileHash);

      var cachedAlbum = _albumRepository.getOrCreateAlbumByServerId(
        song.album.id,
      );
      cachedAlbum.name = song.album.name;
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
