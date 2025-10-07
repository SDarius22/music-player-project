import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:rxdart/rxdart.dart';

class ArtistProvider with ChangeNotifier implements QueryableProvider {
  final ArtistService _artistService;

  bool _isAscending = true;
  String _query = '';
  String _sortField = 'Name'; // Name, Duration, Number of Songs

  late Future artistsFuture;

  ArtistProvider(this._artistService) {
    artistsFuture = Future(() => _artistService.getAllArtists());

    artistsStream.throttleTime(const Duration(seconds: 2)).listen((_) {
      debugPrint("Artists stream updated");
      artistsFuture = Future(
        () => _artistService.getArtists(_query, _sortField, _isAscending),
      );
      notifyListeners();
    });
  }

  Stream get artistsStream => _artistService.watchArtists();

  get sortFields => _artistService.sortFields;

  @override
  bool getFlag() {
    return _isAscending;
  }

  @override
  void setFlag(bool value) {
    _isAscending = value;
    artistsFuture = Future(
      () => _artistService.getArtists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  String getSortField() {
    return _sortField;
  }

  @override
  void setSortField(String field) {
    _sortField = field;
    artistsFuture = Future(
      () => _artistService.getArtists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  void setQuery(String newQuery) {
    _query = newQuery;
    artistsFuture = Future(
      () => _artistService.getArtists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  Artist getArtist(int artistId) {
    return _artistService.getArtist(artistId);
  }

  List<Artist> getArtists() {
    return _artistService.getArtists(_query, _sortField, _isAscending);
  }

  List<Artist> getAllArtists() {
    return _artistService.getAllArtists();
  }
}
