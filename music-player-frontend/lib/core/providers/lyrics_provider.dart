import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyrics_model_builder.dart';
import 'package:music_player_frontend/local_libs/lyric_reader/lyrics_reader_model.dart';

class LyricsProvider with ChangeNotifier {
  late final AbstractAudioProvider _audioProvider;
  late LyricsReaderModel lyricsModelBuilder;
  late String unsyncedLyrics;

  bool hasBeenInitialized = false;

  LyricsProvider(this._audioProvider) {
    if (!hasBeenInitialized) {
      hasBeenInitialized = true;
    }
    buildLyricsModel();
    _audioProvider.addListener(() {
      buildLyricsModel();
    });
  }

  Future<void> buildLyricsModel() async {
    String? lyrics = await _getLyricsForCurrentSong();
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

  Future<String?> _getLyricsForCurrentSong() async {
    return await FileService.getLyrics(
      _audioProvider.audioService.currentSong?.path,
    );
  }
}
