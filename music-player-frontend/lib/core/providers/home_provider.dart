import 'package:flutter/foundation.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/rest_clients/song_rest_service.dart';

class HomeProvider with ChangeNotifier {
  final SongRestService _songRestService;

  List<Song> _recommendations = [];
  List<Song> _forgottenFavourites = [];
  List<Song> _quickDial = [];

  bool _loading = false;
  bool _loaded = false;

  List<Song> get recommendations => _recommendations;
  List<Song> get forgottenFavourites => _forgottenFavourites;
  List<Song> get quickDial => _quickDial;
  bool get loading => _loading;
  bool get loaded => _loaded;

  HomeProvider(this._songRestService);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    final results = await Future.wait([
      _songRestService.getQuickDial(),
      _songRestService.getRecommendations(),
      _songRestService.getForgottenFavourites(),
    ]);

    _quickDial = results[0];
    _recommendations = results[1];
    _forgottenFavourites = results[2];
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loaded = false;
    await load();
  }
}
