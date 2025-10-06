import 'dart:typed_data';

import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/album_repo.dart';

class AlbumService {
  final AlbumRepository _albumRepository;

  AlbumService(this._albumRepository);

  Stream watchAlbums() => _albumRepository.watchAlbums();

  Album getAlbum(int albumId) {
    try {
      return _albumRepository.getAlbum(albumId)!;
    } catch (e) {
      throw Exception("Album with ID $albumId not found.");
    }
  }

  Album getOrCreateAlbum(String albumName, int artistId, {Uint8List? image}) {
    Album? existingAlbum = _albumRepository.getAlbumByNameAndArtist(
      albumName,
      artistId,
    );
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

  Album getAlbumByNameAndArtist(String albumName, int artistId) {
    try {
      return _albumRepository.getAlbumByNameAndArtist(albumName, artistId)!;
    } catch (e) {
      throw Exception(
        "Album with name $albumName and artist ID $artistId not found.",
      );
    }
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    return _albumRepository.getAlbums(query, sortField, flag);
  }

  List<Album> getAllAlbums() {
    return _albumRepository.getAllAlbums();
  }

  void updateAlbum(Album album) {
    _albumRepository.updateAlbum(album);
  }
}
