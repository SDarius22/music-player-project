import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  final SongService _songService;
  final AbstractMusicScannerService _scannerService;

  bool _isInitialized = false;

  List<Song> _recommendations = [];
  List<Song> _forgottenFavourites = [];
  List<Song> _quickDial = [];
  bool _homeLoading = false;
  bool _homeLoaded = false;

  List<Song> get recommendations => _recommendations;

  List<Song> get forgottenFavourites => _forgottenFavourites;

  List<Song> get quickDial => _quickDial;

  bool get homeLoading => _homeLoading;

  bool get homeLoaded => _homeLoaded;

  SongProvider(this._songService, this._scannerService) {
    _scannerService.progressStream.listen((progress) {
      debugPrint("Music scan progress: $progress");
      notifyListeners();
    });
  }

  @override
  Map<String, dynamic> get sortFields => _songService.sortFields;

  String get defaultSortField => 'Title';

  int get totalSongsCount => _songService.getSongCount();

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    debugPrint("Performing initial quick scan...");
    await _scannerService.performQuickScan();
    runSync();

    _isInitialized = true;
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    return await _songService.fetchSongByFileHash(fileHash);
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  ) async {
    final result = await _songService.getSongsPage(
      query,
      sortField,
      ascending,
      page,
      size,
    );
    return PageResult(
      content: result.content,
      totalPages: result.totalPages,
      page: result.page,
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

  Future<void> loadHomeData() async {
    if (_homeLoading) return;
    _homeLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _songService.getQuickDial(),
        _songService.getRecommendations(),
        _songService.getForgottenFavourites(),
      ]);
      _quickDial = results[0];
      _recommendations = results[1];
      _forgottenFavourites = results[2];
    } catch (e) {
      debugPrint('SongProvider: failed to load home data: $e');
    }

    _homeLoading = false;
    _homeLoaded = true;
    notifyListeners();
  }

  Future<void> refreshHomeData() async {
    _homeLoaded = false;
    await loadHomeData();
  }
}
