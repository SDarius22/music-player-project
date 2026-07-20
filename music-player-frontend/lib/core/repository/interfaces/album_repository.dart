import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

abstract class AlbumRepository {
  Map<String, dynamic> get sortFields;

  Album saveAlbum(Album album);

  Album? getAlbumByHash(String albumHash);

  Album getOrCreateAlbum(String albumHash, String albumName, Artist artist);

  int getAlbumCount(String query, bool containLocalOnly);

  List<Album> getAlbumsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  );

  void updateAlbum(Album album);

  void clearAll();
}
