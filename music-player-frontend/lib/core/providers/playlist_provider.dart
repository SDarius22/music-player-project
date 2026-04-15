import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

class PlaylistProvider with ChangeNotifier implements QueryableProvider {
  static final _logger = Logger('PlaylistProvider');

  final PlaylistService _playlistService;

  PlaylistProvider(this._playlistService) {
    playlistsStream.listen((event) {
      _logger.fine('Playlists stream updated');
      notifyListeners();
    });
  }

  Stream get playlistsStream => _playlistService.watchPlaylists();

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final all = _playlistService.getPlaylists(query, sortField, ascending);
    final totalElements = all.length;
    final totalPages = totalElements == 0 ? 1 : (totalElements / size).ceil();
    final offset = page * size;
    final content =
        offset >= totalElements
            ? <Playlist>[]
            : all.sublist(offset, (offset + size).clamp(0, totalElements));
    return PageResult(content: content, totalPages: totalPages, page: page);
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  void addPlaylist(String name, List<Song> songs, Uint8List? coverArt) {
    _playlistService.addPlaylist(name, songs, coverArt);
    notifyListeners();
  }

  void deletePlaylist(Playlist playlist) {
    _playlistService.deletePlaylist(playlist);
    notifyListeners();
  }

  List<Playlist> getIndestructiblePlaylists() {
    return _playlistService.getIndestructiblePlaylists();
  }

  List<Playlist> getNormalPlaylists() {
    return _playlistService.getNormalPlaylists();
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

  void updateFavoritesPlaylist() {
    _playlistService.updateFavoritesPlaylist();
  }
}
