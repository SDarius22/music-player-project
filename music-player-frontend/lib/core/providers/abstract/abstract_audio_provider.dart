import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/queue_song_repo.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

abstract class AbstractAudioProvider with ChangeNotifier {
  late AppAudioService audioService;

  Song get currentSong;

  List<Song> get currentQueue;

  AudioSettings get currentAudioSettings;

  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> balanceNotifier = ValueNotifier<double>(0.0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);

  Future<void> init(
    QueueSongRepository queueSongRepository,
    SettingsService settingsService,
    SongService songService,
    AbstractAudioPlayer audioPlayer,
  );

  Future<void> play();

  Future<void> pause();

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  Future<void> stop();

  Future<void> seek(Duration position);

  void setPlaybackSpeed(double speed);

  void setVolume(double volume);

  void setBalance(double balance);

  void setRepeat(bool repeat);

  void setShuffle(bool shuffle);

  void setQueue(List<Song> songs);

  Future<Duration> getDuration();

  void addToQueue(Song song);

  void addMultipleToQueue(List<Song> songs);

  void addNextToQueue(Song song);

  void addMultipleNextToQueue(List<Song> songs);

  void removeFromQueue(Song song);

  Future<void> setCurrentSong(Song song);

  void likeCurrentSong();
}
