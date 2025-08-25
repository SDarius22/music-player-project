import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';


abstract class AbstractAudioProvider with ChangeNotifier{
  late AppAudioService audioService;

  Song? get currentSong => audioService.currentSong;
  List<String> get currentQueue => audioService.audioSettings.currentQueue;

  Future<AppAudioService> init(SettingsService settingsService, SongService songService, AbstractAudioPlayer audioPlayer);
  Future<void> play();
  Future<void> pause();
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> repeat();

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