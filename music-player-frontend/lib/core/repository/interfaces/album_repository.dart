import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

abstract class AlbumRepository {
  Map<String, dynamic> get sortFields;

  Album saveAlbum(Album album);

  Album? getAlbumByHash(String albumHash);

  Album getOrCreateAlbum(String albumHash, String albumName, Artist artist);

  List<Album> getAlbums(String query, String sortField, bool ascending);

  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  );

  void updateAlbum(Album album);
}
