import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';

class PlaylistProvider with ChangeNotifier implements QueryableProvider {
  final PlaylistService _playlistService;

  PlaylistProvider(this._playlistService);

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  String get defaultSortField => 'Name';

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    bool streamOnly = false,
  }) async {
    final result = await _playlistService.getPlaylistsPage(
      query,
      sortField,
      ascending,
      localOnly,
      page,
      size,
      streamOnly: streamOnly,
    );
    return PageResult(
      content: result.content,
      totalPages: result.totalPages,
      page: result.page,
    );
  }

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async {
    return _playlistService.getPlaylistSongsPageByHash(
      hash,
      localOnly: localOnly,
      page: page,
      size: size,
    );
  }

  Future<PageResult<Song>> getPlaylistSongsPage(
    Playlist playlist, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async {
    return _playlistService.getPlaylistSongsPage(
      playlist,
      localOnly: localOnly,
      page: page,
      size: size,
    );
  }

  @override
  Future<Playlist?> fetchEntity(BaseEntity playlist) async {
    if (playlist is! Playlist) return null;
    return await _playlistService.getPlaylistDetails(playlist);
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  Future<void> addPlaylist(
    String name,
    List<Song> songs,
    Uint8List? coverArt,
  ) async {
    await _playlistService.addPlaylist(name, songs, coverArt);
    notifyListeners();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    await _playlistService.deletePlaylist(playlist);
    notifyListeners();
  }

  Future<({List<Playlist> content, int page, int totalPages})>
  getIndestructiblePlaylists(int page, int size) async {
    return await _playlistService.getIndestructiblePlaylists(page, size);
  }

  Future<({List<Playlist> content, int page, int totalPages})>
  getNormalPlaylists(int page, int size) async {
    return await _playlistService.getNormalPlaylists(page, size);
  }

  Future<void> addSongsToPlaylist(Playlist playlist, List<Song> songs) async {
    await _playlistService.addToPlaylist(playlist, songs);
    notifyListeners();
  }

  Future<void> deleteSongFromPlaylist(Song song, Playlist playlist) async {
    await _playlistService.deleteFromPlaylist(song, playlist);
    notifyListeners();
  }
}
