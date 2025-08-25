import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:rxdart/rxdart.dart';

class SongProvider with ChangeNotifier {
  final SongService _songService;

  bool _isAscending = false;
  String _query = '';
  String _sortField = 'Name'; // Name or Duration

  bool _finishedLoading  = true;

  late Future songsFuture;

  SongProvider(this._songService) {
    songsFuture = Future(() => _songService.getAllSongs());


    songsStream.throttleTime(const Duration(seconds: 10)).listen((_) {
      if (!_finishedLoading) {
        debugPrint("Songs stream updated");
        songsFuture = Future(() => _songService.getSongs(_query, _sortField, _isAscending));
        notifyListeners();
      }
    });
  }

  Stream get songsStream => _songService.watchSongs();

  void setFlag(bool value) {
    _isAscending = value;
    songsFuture = Future(() => _songService.getSongs(_query, _sortField, _isAscending));
    notifyListeners();
  }

  void setSortField(String field) {
    _sortField = field;
    songsFuture = Future(() => _songService.getSongs(_query, _sortField, _isAscending));
    notifyListeners();
  }

  void setQuery(String newQuery) {
    _query = newQuery;
    songsFuture = Future(() => _songService.getSongs(_query, _sortField, _isAscending));
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

  // Future<void> startLoadingSongs() async {
  //   _finishedLoading = false;
  //   debugPrint("Loading songs...");
  //   try {
  //     await _songService.retrieveAllSongs();
  //   } catch (e) {
  //     debugPrint("Error loading songs: $e");
  //   }
  //   _finishedLoading = true;
  // }
}