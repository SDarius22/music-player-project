import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';

abstract class AbstractAudioProvider extends BaseAudioHandler
    with ChangeNotifier {
  final AppAudioService audioService;
  final FileService fileService;

  AbstractAudioProvider(this.audioService, this.fileService);

  ValueNotifier<Song> currentSongNotifier = ValueNotifier<Song>(Song());

  Song get currentSong => audioService.currentSong;

  set currentSong(Song song) {
    currentSongNotifier.value = song;
    audioService.currentSong = song;
  }

  AudioSettings get currentAudioSettings;

  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> balanceNotifier = ValueNotifier<double>(0.0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);

  Future<void> init();

  @override
  Future<void> play();

  @override
  Future<void> pause();

  @override
  Future<void> skipToNext();

  @override
  Future<void> skipToPrevious();

  @override
  Future<void> stop();

  @override
  Future<void> seek(Duration position);

  void setPlaybackSpeed(double speed);

  void setVolume(double volume);

  void setBalance(double balance);

  void setRepeat(bool repeat);

  void setShuffle(bool shuffle);

  Future<void> setQueue(List<Song> songs);

  Future<Duration> getDuration();

  void addToQueue(Song song);

  void addMultipleToQueue(List<Song> songs);

  void addNextToQueue(Song song);

  void addMultipleNextToQueue(List<Song> songs);

  void removeFromQueue(Song song);

  Future<void> setCurrentSong(Song song);

  void likeCurrentSong();
}
