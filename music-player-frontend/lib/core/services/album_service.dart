import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/repository/album_repo.dart';

class AlbumService {
  final AlbumRepository _albumRepository;

  AlbumService(this._albumRepository);

  Stream watchAlbums() => _albumRepository.watchAlbums();

  Album addAlbum(String name) {
    Album album = Album();
    album.name = name;
    return _albumRepository.saveAlbum(album);
  }

  Album? getAlbum(int albumId) {
    return _albumRepository.getAlbum(albumId);
  }

  List<Album> getAlbums(String query, String sortField, bool flag) {
    return _albumRepository.getAlbums(query, sortField, flag);
  }

  List<Album> getAllAlbums() {
    return _albumRepository.getAllAlbums();
  }

  void deleteAlbum(Album album) {
    _albumRepository.deleteAlbum(album);
  }

  void updateAlbum(Album album) {
    _albumRepository.saveAlbum(album);
  }
}