import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

class PlaylistProvider with ChangeNotifier {
  final PlaylistService _playlistService;

  bool _isAscending = false;
  String _query = '';
  String _sortField = 'Name'; // Name, Duration, Number of Songs, Created At

  late Future playlistsFuture;

  PlaylistProvider(this._playlistService) {
    playlistsFuture = Future(() => _playlistService.getAllPlaylists());

    playlistsStream.listen((_) {
      debugPrint("Playlists stream updated");
      playlistsFuture = Future(() => _playlistService.getPlaylists(_query, _sortField, _isAscending));
      notifyListeners();
    });
  }

  Stream get playlistsStream => _playlistService.watchPlaylists();

  void setFlag(bool value) {
    _isAscending = value;
    playlistsFuture = Future(() => _playlistService.getPlaylists(_query, _sortField, _isAscending));
    notifyListeners();
  }

  void setSortField(String field) {
    _sortField = field;
    playlistsFuture = Future(() => _playlistService.getPlaylists(_query, _sortField, _isAscending));
    notifyListeners();
  }

  void setQuery(String newQuery) {
    _query = newQuery;
    playlistsFuture = Future(() => _playlistService.getPlaylists(_query, _sortField, _isAscending));
    notifyListeners();
  }

  void addPlaylist(String name, List<Song> songs, String whereToAdd, Uint8List? coverArt) {
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


  void addSongsToPlaylist(Playlist playlist, List<Song> songs) {
    _playlistService.addToPlaylist(playlist, songs);
    notifyListeners();
  }

  void deleteSongFromPlaylist(Playlist playlist, Song song) {
    _playlistService.deleteFromPlaylist(playlist, song);
    notifyListeners();
  }
}