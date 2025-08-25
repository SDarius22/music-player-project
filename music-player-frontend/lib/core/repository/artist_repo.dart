import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

class ArtistRepository {
  get artistBox => ObjectBox.store.box<Artist>();

  void addArtist(Artist artist) {
    artistBox.put(artist);
  }

  Stream watchAllArtists() {
    final query = artistBox._query();
    return query.watch();
  }

  Artist? getArtist(String name) {
    return artistBox._query(Artist_.name.equals(name)).build().findUnique();
  }

  List<Artist> getArtists(String query, String sortField, bool flag)  {
    Query<Artist> builderQuery;
    if (flag == false) {
      builderQuery = artistBox
          ._query(Artist_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Artist_.name : Artist_.duration,
      ).build();
    } else {
      builderQuery = artistBox
          ._query(Artist_.name.contains(query, caseSensitive: false))
          .order(
        sortField == 'Name' ? Artist_.name : Artist_.duration,
        flags: Order.descending,
      ).build();
    }
    return builderQuery.find();
  }

  List<Artist> getAllArtists()  {
    return artistBox._query().order(Artist_.name).build().find();
  }

  void deleteArtist(Artist artist)  {
    artistBox.remove(artist.id);
  }

  void updateArtist(Artist artist)  {
    artistBox.put(artist);
  }
}