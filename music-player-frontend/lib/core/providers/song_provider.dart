import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/music_scanner_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:rxdart/rxdart.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  final SongService _songService;
  final MusicScannerService _scannerService;

  bool _isAscending = true;
  String _query = '';
  String _sortField = 'Title';

  bool _isInitialized = false;

  late Future songsFuture;

  SongProvider(this._songService, this._scannerService) {
    songsFuture = Future(() => _songService.getAllSongs());

    songsStream.throttleTime(const Duration(seconds: 2)).listen((_) {
      debugPrint("Songs stream updated");
      songsFuture = Future(
        () => _songService.getSongs(_query, _sortField, _isAscending),
      );
      notifyListeners();
    });
  }

  Stream get songsStream => _songService.watchSongs();

  @override
  get sortFields => _songService.sortFields;

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    debugPrint("Initializing SongProvider...");

    // Check if this is the first scan
    if (!_songService.isInitialScanComplete()) {
      debugPrint("Performing initial quick scan...");

      // Perform quick scan - adds songs with basic info (just filenames)
      await _scannerService.performQuickScan(musicDirectories);

      // Mark scan as complete
      _songService.markInitialScanComplete();

      // Start enriching metadata in background
      _enrichMetadataInBackground();
    } else {
      debugPrint("Initial scan already complete, loading from database");
    }

    // Load songs from database
    // _refreshSongs();
    _isInitialized = true;
  }

  // Enrich metadata in background
  void _enrichMetadataInBackground() async {
    notifyListeners();

    debugPrint("Starting metadata enrichment...");
    bool refresh = await _scannerService.enrichMetadata();

    debugPrint("Metadata enrichment complete!");

    // Refresh songs to show updated metadata
    if (refresh) {
      _refreshSongs();
    }
  }

  // Refresh songs from database with current filters
  void _refreshSongs() {
    songsFuture = Future(
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
    songsFuture = Future(
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
    songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  @override
  void setQuery(String newQuery) {
    if (newQuery == _query) return;
    _query = newQuery;
    songsFuture = Future(
      () => _songService.getSongs(_query, _sortField, _isAscending),
    );
    notifyListeners();
  }

  void addSong(String songPath) {
    _songService.addSong(songPath);
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
}
