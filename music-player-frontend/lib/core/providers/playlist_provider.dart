import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

class PlaylistProvider with ChangeNotifier implements QueryableProvider {
  final PlaylistService _playlistService;

  bool _isAscending = true;
  String _query = '';
  String _sortField = 'Name';

  late Future _playlistsFuture;

  PlaylistProvider(this._playlistService) {
    _playlistsFuture = Future(() => _playlistService.getAllPlaylists());

    playlistsStream.listen((event) {
      debugPrint("Playlists stream updated with ${event.toString()} playlists");
      _playlistsFuture = Future(
        () => _playlistService.getPlaylists(_query, _sortField, _isAscending),
      );
      notifyListeners();
    });
  }

  Stream get playlistsStream => _playlistService.watchPlaylists();

  @override
  get sortFields => _playlistService.sortFields;

  @override
  Future get query => _playlistsFuture;

  @override
  bool getFlag() {
    return _isAscending;
  }

  @override
  void setFlag(bool value) {
    _isAscending = value;
    _playlistsFuture = Future(
      () => _playlistService.getPlaylists(_query, _sortField, _isAscending),
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
    _playlistsFuture = Future(
      () => _playlistService.getPlaylists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  void setQuery(String newQuery) {
    _query = newQuery;
    _playlistsFuture = Future(
      () => _playlistService.getPlaylists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  void addPlaylist(
    String name,
    List<Song> songs,
    String whereToAdd,
    Uint8List coverArt,
  ) {
    _playlistService.addPlaylist(name, songs, whereToAdd, coverArt);
    notifyListeners();
  }

  void deletePlaylist(Playlist playlist) {
    _playlistService.deletePlaylist(playlist);
    notifyListeners();
  }

  Playlist? getPlaylist(int playlistId) {
    return _playlistService.getPlaylist(playlistId);
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistService.getIndestructiblePlaylists();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistService.getNormalPlaylists();
  }

  List<Playlist> getPlaylists() {
    return _playlistService.getPlaylists(_query, _sortField, _isAscending);
  }

  List<Playlist> getAllPlaylists() {
    return _playlistService.getAllPlaylists();
  }

  void addSongsToPlaylist(Playlist playlist, List<Song> songs) {
    _playlistService.addToPlaylist(playlist, songs);
    notifyListeners();
  }

  void deleteSongFromPlaylist(Song song, Playlist playlist) {
    _playlistService.deleteFromPlaylist(song, playlist);
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    _playlistsFuture = Future(
      () => _playlistService.getPlaylists(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }
}
