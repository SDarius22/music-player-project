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

  LyricsProvider(this._lyricsService, this._audioService) {
    if (!_hasBeenInitialized) {
      _hasBeenInitialized = true;
    }
    _buildLyricsModel();

    _audioService.currentSongNotifier.addListener(() {
      _buildLyricsModel();
    });
  }

  void _buildLyricsModel() async {
    loadingNotifier.value = true;
    unsyncedLyrics =
        await _lyricsService.fetchLyricsForSong(_audioService.currentSong) ??
        'No lyrics available';
    lyricsModelBuilder =
        LyricsModelBuilder.create()
            .bindLyricToMain(getUnsyncedLyrics())
            .getModel();
    _logger.fine(
      'LyricsModelBuilder: ${lyricsModelBuilder.lyrics.length} lines',
    );
    loadingNotifier.value = false;
  }

  String getUnsyncedLyrics() {
    return unsyncedLyrics;
  }
}
