import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/artist.dart';

class ArtistService {
  Box<Artist> get _artistBox => ObjectBox.store.box<Artist>();

  Stream watchArtists() => _artistBox.query().watch(triggerImmediately: true);

  Artist addArtist(String name) {
    Artist artist = Artist();
    artist.name = name;
    artist.id = _artistBox.put(artist);
    return artist;
  }

  Artist? getArtist(int artistId) {
    return _artistBox.get(artistId);
  }

  List<Artist> getArtists(String query, String sortField, bool flag) {
    Query<Artist> builderQuery;
    try {
      if (flag == false) {
        builderQuery = _artistBox
            .query(Artist_.name.contains(query, caseSensitive: false))
            .order(Artist_.name)
            .build();
      } else {
        builderQuery = _artistBox
            .query(Artist_.name.contains(query, caseSensitive: false))
            .order(Artist_.name, flags: Order.descending)
            .build();
      }
      return builderQuery.find();
    } catch (e) {
      debugPrint("Error fetching artists: $e");
      return [];
    }
  }

  List<Artist> getAllArtists() {
    return _artistBox.getAll();
  }

  void updateArtist(Artist artist) {
    _artistBox.put(artist);
  }

  void deleteArtist(Artist artist) {
    _artistBox.remove(artist.id);
  }
}