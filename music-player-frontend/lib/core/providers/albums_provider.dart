import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:rxdart/rxdart.dart';

class AlbumProvider with ChangeNotifier {
  final AlbumService _albumService;

  bool _isAscending = false;
  String _query = '';
  String _sortField = 'Name'; // Name, Duration, Number of Songs

  late Future albumsFuture;

  AlbumProvider(this._albumService) {
    albumsFuture = Future(() => _albumService.getAllAlbums());

    albumsStream.debounceTime(const Duration(seconds: 10)).listen((_) {
      debugPrint("Albums stream updated");
      albumsFuture = Future(
        () => _albumService.getAlbums(_query, _sortField, _isAscending),
      );
      notifyListeners();
    });
  }

  Stream get albumsStream => _albumService.watchAlbums();

  void setFlag(bool value) {
    _isAscending = value;
    albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  String getSortField() {
    return _sortField;
  }

  void setSortField(String field) {
    _sortField = field;
    albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  void setQuery(String newQuery) {
    _query = newQuery;
    albumsFuture = Future(
      () => _albumService.getAlbums(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  void addAlbum(String name) {
    _albumService.addAlbum(name);
    notifyListeners();
  }

  void deleteAlbum(Album album) {
    _albumService.deleteAlbum(album);
    notifyListeners();
  }

  void updateAlbum(Album album) {
    _albumService.updateAlbum(album);
    notifyListeners();
  }

  Album? getAlbum(int albumId) {
    return _albumService.getAlbum(albumId);
  }

  List<Album> getAlbums() {
    return _albumService.getAlbums(_query, _sortField, _isAscending);
  }

  List<Album> getAllAlbums() {
    return _albumService.getAllAlbums();
  }
}
