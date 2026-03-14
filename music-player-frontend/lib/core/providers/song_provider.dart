import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  final SongService _songService;
  final AbstractMusicScannerService _scannerService;
  bool _isAscending = true;
  String _query = '';
  String _sortField = 'Title';

  bool _isInitialized = false;
  bool _preferServer = false;
  bool _fallbackToServer = false;

  late Future _songsFuture;

  SongProvider(this._songService, this._scannerService) {
    _songsFuture = _songService.getAllSongs(
      preferServer: _preferServer,
      fallbackToServer: _fallbackToServer,
    );
    _scannerService.progressStream.listen((progress) {
      debugPrint("Music scan progress: $progress");
      refreshSongs();
    });
  }

  @override
  get sortFields => _songService.sortFields;

  @override
  Future get query => _songsFuture;

  int get totalSongsCount => _songService.getSongCount();

  set preferServer(bool value) {
    _preferServer = value;
  }

  set fallbackToServer(bool value) {
    _fallbackToServer = value;
  }

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    debugPrint("Performing initial quick scan...");

    await _scannerService.performQuickScan();
    runSync();

    _isInitialized = true;
  }

  void refreshSongs() {
    debugPrint(
      "Refreshing songs with query '$_query', sortField '$_sortField', isAscending '$_isAscending'",
    );
    _songsFuture = _songService.getSongs(
      _query,
      _sortField,
      _isAscending,
      preferServer: _preferServer,
      fallbackToServer: _fallbackToServer,
    );
    notifyListeners();
  }

  @override
  bool getFlag() {
    return _isAscending;
  }

  @override
  void setFlag(bool value) {
    _isAscending = value;
    _songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
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
    _songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  void setQuery(String newQuery) {
    if (newQuery == _query) return;
    _query = newQuery;
    _songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
    );
    notifyListeners();
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

  @override
  Future<void> refresh() async {
    _songsFuture = _songService.getAllSongs(
      preferServer: _preferServer,
      fallbackToServer: _fallbackToServer,
    );
    notifyListeners();
  }

  void runSync() async {
    _songService.runSync();
    refreshSongs();
  }
}
