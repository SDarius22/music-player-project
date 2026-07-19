import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/lyrics_service.dart';
import 'package:lyric_reader/lyrics_model_builder.dart';
import 'package:lyric_reader/lyrics_reader_model.dart';

class LyricsProvider with ChangeNotifier {
  static final _logger = Logger('LyricsProvider');

  final LyricsService _lyricsService;
  final AppAudioService _audioService;
  LyricsReaderModel lyricsModelBuilder = LyricsReaderModel();
  String unsyncedLyrics = 'No lyrics available';
  bool _hasBeenInitialized = false;
  ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(false);
  int _requestId = 0;

  LyricsProvider(this._lyricsService, this._audioService) {
    if (!_hasBeenInitialized) {
      _hasBeenInitialized = true;
    }
    _buildLyricsModel();

    _audioService.currentSongNotifier.addListener(() {
      _buildLyricsModel();
    });
  }

  Future<void> _buildLyricsModel() async {
    final requestId = ++_requestId;
    final song = _audioService.currentSong;
    loadingNotifier.value = true;
    final lyrics = await _lyricsService.fetchLyricsForSong(song);
    if (requestId != _requestId || song != _audioService.currentSong) return;
    _setLyrics(lyrics ?? 'No lyrics available');
    loadingNotifier.value = false;
  }

  Future<bool> markLyricsIncorrect() async {
    final requestId = ++_requestId;
    final song = _audioService.currentSong;
    if (song == null) return false;
    loadingNotifier.value = true;
    final lyrics = await _lyricsService.findAlternativeLyrics(song);
    if (requestId != _requestId || song != _audioService.currentSong) {
      return false;
    }
    if (lyrics == null) {
      loadingNotifier.value = false;
      return false;
    }
    _setLyrics(lyrics);
    loadingNotifier.value = false;
    return true;
  }

  Future<bool> saveLyricsLocally() => _lyricsService.saveLyricsLocally(
    _audioService.currentSong,
    unsyncedLyrics,
  );

  Future<bool> updateLyrics(String lyrics) async {
    final song = _audioService.currentSong;
    final saved = await _lyricsService.updateLyrics(song, lyrics);
    if (saved && song == _audioService.currentSong) _setLyrics(lyrics);
    return saved;
  }

  void _setLyrics(String lyrics) {
    unsyncedLyrics = lyrics;
    lyricsModelBuilder =
        LyricsModelBuilder.create()
            .bindLyricToMain(getUnsyncedLyrics())
            .getModel();
    _logger.fine(
      'LyricsModelBuilder: ${lyricsModelBuilder.lyrics.length} lines',
    );
    notifyListeners();
  }

  String getUnsyncedLyrics() {
    return unsyncedLyrics;
  }
}
