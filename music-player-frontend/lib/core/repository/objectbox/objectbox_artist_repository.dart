import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';

class ObjectBoxArtistRepository implements ArtistRepository {
  Box<Artist> get _artistBox => ObjectBox.store.box<Artist>();

  @override
  Map<String, dynamic> get sortFields => {'Name': Artist_.name};

  @override
  Artist saveArtist(Artist artist) {
    artist.id = _artistBox.put(artist);
    return artist;
  }

  @override
  Artist? getArtistByHash(String artistHash) {
    return _artistBox
        .query(Artist_.hash.equals(artistHash))
        .build()
        .findFirst();
  }

  @override
  Artist getOrCreateArtist(String artistHash, String name) {
    final existing = getArtistByHash(artistHash);
    if (existing != null) return existing;
    Artist artist = Artist(artistHash, name);
    return saveArtist(artist);
  }

  @override
  List<Artist> getArtists(String query, String sortField, bool ascending) {
    Query<Artist> builderQuery;
    if (ascending) {
      builderQuery =
          _artistBox
              .query(Artist_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Artist_.name,
              )
              .build();
    } else {
      builderQuery =
          _artistBox
              .query(Artist_.name.contains(query, caseSensitive: false))
              .order(
                sortFields.containsKey(sortField)
                    ? sortFields[sortField]
                    : Artist_.name,
                flags: Order.descending,
              )
              .build();
    }
    return builderQuery.find();
  }

  @override
  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final q =
        _artistBox
            .query(Artist_.name.contains(query, caseSensitive: false))
            .order(
              sortFields.containsKey(sortField)
                  ? sortFields[sortField]
                  : Artist_.name,
              flags: ascending ? 0 : Order.descending,
            )
            .build();
    q.offset = offset;
    q.limit = limit;
    return q.find();
  }

  @override
  void updateArtist(Artist artist) {
    _artistBox.put(artist);
  }
}
