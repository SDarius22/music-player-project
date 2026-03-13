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

  late Future _songsFuture;

  SongProvider(this._songService, this._scannerService) {
    _songsFuture = Future(() => _songService.getAllSongs());
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
    _songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
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

  Song? getSong(String songPath) {
    return _songService.getSong(songPath);
  }

  Song? getSongContaining(String query) {
    return _songService.getSongContaining(query);
  }

  List<Song> getSongs(String query, String sortField, bool flag) {
    return _songService.getSongs(query, sortField, flag);
  }

  List<Song> getSongsFromPaths(List<String> paths) {
    return _songService.getSongsFromPaths(paths);
  }

  List<Song> getAllSongs() {
    return _songService.getAllSongs();
  }

  @override
  Future<void> refresh() async {
    _songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  void runSync() async {
    _songService.runSync();
    refreshSongs();
  }
}
