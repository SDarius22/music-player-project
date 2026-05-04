import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class SongProvider with ChangeNotifier implements QueryableProvider {
  static final _logger = Logger('SongProvider');

  final SongService _songService;
  final AbstractMusicScannerService _scannerService;

  bool _isInitialized = false;

  SongProvider(this._songService, this._scannerService) {
    _scannerService.progressStream.listen((progress) {
      _logger.fine('Music scan progress: $progress');
      notifyListeners();
    });
  }

  @override
  Map<String, dynamic> get sortFields => _songService.sortFields;

  String get defaultSortField => 'Title';

  Future<void> initialize(List<String> musicDirectories) async {
    if (_isInitialized) return;

    // _scannerService.performQuickScan();
    // runSync();

    _isInitialized = true;
  }

  Future<Song> enrichSong(Song song) async {
    return await _songService.fullyFetchSong(song);
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    return await _songService.fetchSongByFileHash(fileHash);
  }

  @override
  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size,
  ) async {
    final result = await _songService.getSongsPage(
      query,
      sortField,
      ascending,
      localOnly,
      page,
      size,
    );
    return PageResult(
      content: result.content,
      totalPages: result.totalPages,
      page: result.page,
    );
  }

  Future<List<Song>> fetchRecommendedSongs() async {
    return await _songService.getRecommendations();
  }

  Future<List<Song>> fetchRediscoverSongs() async {
    return await _songService.getForgottenFavourites();
  }

  Future<List<Song>> fetchJumpBackSongs() async {
    return await _songService.getQuickDial();
  }

  void removeSong(Song song) {
    _songService.deleteSong(song);
    notifyListeners();
  }

  Future<void> updateSong(Song song) async {
    await _songService.updateSong(song);
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  void refreshSongs() {
    notifyListeners();
  }
}
