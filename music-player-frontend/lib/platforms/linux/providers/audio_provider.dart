import 'dart:io';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/abstract/player_state.dart';
import 'package:music_player_frontend/core/providers/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/platforms/linux/entities/concrete_audio_player.dart';
import 'package:music_player_frontend/platforms/linux/system_audio_handlers/system_audio_handler.dart';

class AudioProvider extends AbstractAudioProvider {
  bool hasBeenInitialized = false;
  late Future queueFuture;

  @override
  Future<void> init(SettingsService settingsService, SongService songService, AbstractAudioPlayer audioPlayer) async {
    if (!hasBeenInitialized) {
      var audioHandler = await platform_service.AudioService.init(
        builder: () => SystemAudioHandler(
          AppAudioService(settingsService, songService, audioPlayer),
        ),
        config: const platform_service.AudioServiceConfig(
          androidNotificationChannelId: 'com.example.musicplayer',
          androidNotificationChannelName: 'Music Player',
          androidNotificationOngoing: true,
        ),
      );
      super.audioService = audioHandler.audioService;
      hasBeenInitialized = true;
    }
    await super.audioService.updateCurrentSong();
    await super.audioService.initSettings();
    queueFuture = Future(() => super.audioService.getQueue());
    repeatNotifier.value = super.audioService.audioSettings.repeat;
    shuffleNotifier.value = super.audioService.audioSettings.shuffle;
    sliderNotifier.value = super.audioService.audioSettings.slider;
    balanceNotifier.value = super.audioService.audioSettings.balance;
    volumeNotifier.value = super.audioService.audioSettings.volume;

    super.audioService.audioPlayer.onPositionChanged.listen((Duration event) {
      sliderNotifier.value = event.inMilliseconds;
      super.audioService.setSlider(event.inMilliseconds);
    });
    audioPlayer.onPlayerStateChanged.listen((state) {
      playingNotifier.value = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        if (super.audioService.audioSettings.repeat) {
          debugPrint("Repeat is enabled, repeating song");
          repeat();
        } else {
          skipToNext();
        }
      }
    });
    notifyListeners();
  }


  @override
  Future<void> play() async {
    await super.audioService.play();
  }

  @override
  Future<void> pause() async {
    await super.audioService.pause();
  }

  @override
  Future<void> skipToNext() async {
    await super.audioService.skipToNext();
    notifyListeners();
  }

  @override
  Future<void> skipToPrevious() async {
    await super.audioService.skipToPrevious();
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await super.audioService.stop();
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    sliderNotifier.value = position.inMilliseconds;
    await super.audioService.seek(position);
  }

  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    if (Platform.isLinux){
      super.audioService.setPlaybackSpeed(speed);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setPlaybackSpeed(speed);
    // }
  }

  void setVolume(double volume) {
    volumeNotifier.value = volume;
    if (Platform.isLinux){
      super.audioService.setVolume(volume);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setVolume(volume);
    // }
  }

  void setBalance(double balance) {
    balanceNotifier.value = balance;
    if (Platform.isLinux){
      super.audioService.setBalance(balance);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setBalance(balance);
    // }
  }

  void setRepeat(bool repeat) {
    repeatNotifier.value = repeat;
    if (Platform.isLinux){
      super.audioService.setRepeat(repeat);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setRepeat(repeat);
    // }
  }

  void setShuffle(bool shuffle) {
    shuffleNotifier.value = shuffle;
    if (Platform.isLinux){
      super.audioService.setShuffle(shuffle);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setShuffle(shuffle);
    // }
  }

  void setQueue(List<String> songs) {
    if (Platform.isLinux){
      super.audioService.setQueue(songs);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.setQueue(songs);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  Future<Duration> getDuration() async {
    if (Platform.isLinux){
      return await super.audioService.getDuration() ?? Duration.zero;
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   return await apc.getDuration();
    // }
    return Duration.zero;
  }

  void addToQueue(String songPath) {
    if (Platform.isLinux){
      super.audioService.addToQueue(songPath);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.addToQueue(songPath);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  void addMultipleToQueue(List<String> songPaths) {
    if (Platform.isLinux){
      super.audioService.addMultipleToQueue(songPaths);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.addMultipleToQueue(songPaths);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  void addNextToQueue(String songPath) {
    if (Platform.isLinux){
      super.audioService.addToQueueAtIndex(
        songPath,
        super.audioService.audioSettings.currentQueue.indexOf(currentSong.path) + 1
      );
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.addNextToQueue(songPath);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  void addMultipleNextToQueue(List<String> songPaths) {
    if (Platform.isLinux){
      super.audioService.addMultipleToQueueAtIndex(
        songPaths,
        super.audioService.audioSettings.currentQueue.indexOf(currentSong.path) + 1
      );
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.addMultipleNextToQueue(songPaths);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  void removeFromQueue(String songPath) {
    if (Platform.isLinux){
      super.audioService.removeFromQueue(songPath);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.removeFromQueue(songPath);
    // }
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  Future<void> setCurrentIndex(String path) async {
    if (Platform.isLinux){
      await super.audioService.setCurrentIndex(path);
    }
    // else if (Platform.isWindows){
    //   final apc = AudioPlayerController();
    //   await apc.updateCurrentSong();
    // }
    notifyListeners();
  }

    // try{
    //   File lastFile = File(_filePath);
    //   if (lastFile.existsSync()) {
    //     lastFile.deleteSync();
    //   }
    //   _filePath = path;
    // }
    // catch(e){
    //   debugPrint(e.toString());
    // }
}