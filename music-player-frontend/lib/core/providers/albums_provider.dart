import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:rxdart/rxdart.dart';

class AlbumProvider with ChangeNotifier implements QueryableProvider {
  final AlbumService _albumService;

  bool _isAscending = true;
  String _query = '';
  String _sortField = 'Name';

  late Future _albumsFuture;

  AlbumProvider(this._albumService) {
    _albumsFuture = Future(() => _albumService.getAllAlbums());

    albumsStream.throttleTime(const Duration(seconds: 2)).listen((_) {
      debugPrint("Albums stream updated");
      _albumsFuture = Future(
        () => _albumService.getAlbums(_query, _sortField, _isAscending),
      );
      notifyListeners();
    });
  }

  Stream get albumsStream => _albumService.watchAlbums();

  @override
  get sortFields => _albumService.sortFields;

  @override
  Future get query => _albumsFuture;

  @override
  bool getFlag() {
    return _isAscending;
  }

  @override
  void setFlag(bool value) {
    _isAscending = value;
    _albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
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
    _albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  void setQuery(String newQuery) {
    _query = newQuery;
    _albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  Album getAlbum(int albumId) {
    return _albumService.getAlbum(albumId);
  }

  List<Album> getAlbums() {
    return _albumService.getAlbums(_query, _sortField, _isAscending);
  }

  List<Album> getAllAlbums() {
    return _albumService.getAllAlbums();
  }

  @override
  Future<void> refresh() async {
    _albumsFuture = Future(() => _albumService.getAllAlbums());
    notifyListeners();
  }
}
