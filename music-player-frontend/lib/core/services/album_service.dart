import 'dart:typed_data';

import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';

class AlbumService {
  final AlbumRepository _albumRepository;

  AlbumService(this._albumRepository);

  Stream watchAlbums() => _albumRepository.watchAlbums();

  Map<String, dynamic> get sortFields => _albumRepository.sortFields;

  Album getAlbum(int albumId) {
    try {
      return _albumRepository.getAlbum(albumId)!;
    } catch (e) {
      throw Exception("Album with ID $albumId not found.");
    }
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
    newAlbum.imageBytes =
        albumName == 'Unknown Album' ? Constants.logoBytes : image;
    newAlbum.artist.targetId = artistId;
    return _albumRepository.saveAlbum(newAlbum);
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    return _albumRepository.getAlbums(query, sortField, flag);
  }

  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    int page,
    int pageSize,
  ) {
    return _albumRepository.getAlbumsPaged(
      query,
      sortField,
      ascending,
      page * pageSize,
      pageSize,
    );
  }

  List<Album> getAllAlbums() {
    return _albumRepository.getAllAlbums();
  }

  void updateAlbum(Album album) {
    _albumRepository.updateAlbum(album);
  }
}
