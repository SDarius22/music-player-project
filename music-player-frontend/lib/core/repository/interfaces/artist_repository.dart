import 'package:music_player_frontend/core/entities/artist.dart';

abstract class ArtistRepository {
  Stream watchArtists();

  Map<String, dynamic> get sortFields;

  Artist saveArtist(Artist artist);

  Artist? getArtist(int artistId);

  Artist? getArtistByName(String artistName);

  Artist? getArtistByServerId(int serverId);

  List<Artist> getArtists(String query, String sortField, bool ascending);

  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  );

  List<Artist> getAllArtists();

  void updateArtist(Artist artist);
}
