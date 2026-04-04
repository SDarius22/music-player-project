import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';

class ObjectBoxArtistRepository implements ArtistRepository {
  Box<Artist> get _artistBox => ObjectBox.store.box<Artist>();

  @override
  Stream watchArtists() => _artistBox.query().watch(triggerImmediately: true);

  @override
  Map<String, dynamic> get sortFields => {'Name': Artist_.name};

  @override
  Artist saveArtist(Artist artist) {
    artist.id = _artistBox.put(artist);
    return artist;
  }

  @override
  Artist? getArtist(int artistId) {
    return _artistBox.get(artistId);
  }

  @override
  Artist? getArtistByName(String artistName) {
    return _artistBox
        .query(Artist_.name.equals(artistName))
        .build()
        .findFirst();
  }

  @override
  Artist? getArtistByServerId(int serverId) {
    return _artistBox
        .query(Artist_.serverId.equals(serverId))
        .build()
        .findFirst();
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
  List<Artist> getAllArtists() {
    return _artistBox.getAll();
  }

  @override
  void updateArtist(Artist artist) {
    _artistBox.put(artist);
  }
}
