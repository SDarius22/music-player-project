import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyrics_model_builder.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyrics_reader_model.dart';

class LyricsProvider with ChangeNotifier {
  final AudioProvider _audioProvider;
  final AbstractFileService _fileService;
  LyricsReaderModel lyricsModelBuilder = LyricsReaderModel();
  String unsyncedLyrics = '';
  bool _hasBeenInitialized = false;

  LyricsProvider(this._audioProvider, this._fileService) {
    if (!_hasBeenInitialized) {
      _hasBeenInitialized = true;
    }
    _audioProvider.currentSongNotifier.addListener(() {
      buildLyricsModel();
    });
  }

  void buildLyricsModel() {
    String? lyrics = _getLyricsForCurrentSong();
    lyricsModelBuilder =
        LyricsModelBuilder.create().bindLyricToMain(lyrics ?? '').getModel();
    debugPrint('LyricsModelBuilder: ${lyricsModelBuilder.lyrics.length} lines');
    if (lyricsModelBuilder.lyrics.isEmpty) {
      unsyncedLyrics = lyrics ?? '';
    } else {
      unsyncedLyrics = '';
    }
    notifyListeners();
  }

  String? _getLyricsForCurrentSong() {
    return _fileService.getLyrics(_audioProvider.currentSong?.path);
  }
}
