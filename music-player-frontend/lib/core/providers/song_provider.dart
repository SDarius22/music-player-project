import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
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

  @override
  Future<Song?> fetchEntity(BaseEntity song) async {
    return await _songService.fetchSongByFileHash(song.getHash());
  }

  @override
  Future<PageResult<Song>> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
  }) async {
    return await _songService.getSongsPage(
      query,
      sortField,
      filterAlbumHash,
      filterArtistHash,
      filterPlaylistId,
      ascending,
      localOnly,
      page,
      size,
    );
  }

  Future<List<Song>> fetchRecommendedSongs() async {
    return (await _songService.getRecommendations(0, 10)).content;
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

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) {
    throw UnimplementedError('getSongsPage is not supported in SongProvider');
  }
}
