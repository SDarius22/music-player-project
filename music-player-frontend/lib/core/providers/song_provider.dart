import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  final SongService _songService;
  final AbstractMusicScannerService _scannerService;

  bool _isInitialized = false;
  bool _preferServer = false;
  bool _fallbackToServer = false;

  SongProvider(this._songService, this._scannerService) {
    _scannerService.progressStream.listen((progress) {
      debugPrint("Music scan progress: $progress");
      notifyListeners();
    });
  }

  @override
  Map<String, dynamic> get sortFields => _songService.sortFields;

  String get defaultSortField => 'Title';

  set preferServer(bool value) {
    _preferServer = value;
  }

  set fallbackToServer(bool value) {
    _fallbackToServer = value;
  }

  int get totalSongsCount => _songService.getSongCount();

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    debugPrint("Performing initial quick scan...");
    await _scannerService.performQuickScan();
    runSync();

    _isInitialized = true;
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final dto = await _songService.getSongsPage(
      query,
      sortField,
      ascending,
      page,
      size,
    );
    return PageResult(
      content: dto.content,
      totalPages: dto.totalPages,
      page: dto.page,
    );
  }

  void removeSong(Song song) {
    _songService.deleteSong(song);
    notifyListeners();
  }

  void updateSong(Song song) {
    _songService.updateSong(song);
    notifyListeners();
  }

  Song? getSongContaining(String query) {
    return _songService.getSongContaining(query);
  }

  Future<List<Song>> getSongs(String query, String sortField, bool flag) async {
    return await _songService.getSongs(
      query,
      sortField,
      flag,
      preferServer: _preferServer,
      fallbackToServer: _fallbackToServer,
    );
  }

  Future<List<Song>> getSongsFromPaths(List<String> paths) async {
    return await _songService.getSongsFromPaths(paths);
  }

  Future<List<Song>> getAllSongs() async {
    return await _songService.getAllSongs(
      preferServer: _preferServer,
      fallbackToServer: _fallbackToServer,
    );
  }

  CachedNetworkImage getCoverArt(int serverId) {
    return _songService.getCoverArt(serverId);
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  void refreshSongs() {
    notifyListeners();
  }

  void runSync() async {
    _songService.runSync();
    notifyListeners();
  }
}
