import 'package:music_player_frontend/core/entities/artist.dart';

abstract class ArtistRepository {
  Map<String, dynamic> get sortFields;

  Artist saveArtist(Artist artist);

  Artist? getArtistByHash(String artistName);

  Artist getOrCreateArtist(String artistHash, String artistName);

  int getArtistCount(String query, bool containLocalOnly);

  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    bool containLocalOnly,
    int offset,
    int limit,
  );

  void updateArtist(Artist artist);
}
