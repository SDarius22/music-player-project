import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_audio_player.dart';
import 'package:music_player_frontend/core/services/abstract_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';


abstract class AbstractAudioProvider with ChangeNotifier{
  late AppAudioService audioService;

  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> balanceNotifier = ValueNotifier<double>(0.0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);

  Future<void> init(SettingsService settingsService, SongService songService, AbstractAudioPlayer audioPlayer);
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
  void setQueue(List<String> songs);
  Future<Duration> getDuration();

  void addToQueue(String songPath);
  void addMultipleToQueue(List<String> songPaths);

  void addNextToQueue(String songPath);
  void addMultipleNextToQueue(List<String> songPaths);
  void removeFromQueue(String songPath);

  Future<void> setCurrentIndex(String path);
}