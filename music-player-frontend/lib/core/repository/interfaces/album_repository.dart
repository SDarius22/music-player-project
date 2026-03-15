import 'package:music_player_frontend/core/entities/album.dart';

abstract class AlbumRepository {
  Stream watchAlbums();

  Map<String, dynamic> get sortFields;

  Album saveAlbum(Album album);

  Album? getAlbum(int albumId);

  Album? getAlbumByName(String albumName);

  List<Album> getAlbums(String query, String sortField, bool ascending);

  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  );

  List<Album> getAllAlbums();

  void updateAlbum(Album album);
}
