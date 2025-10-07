import 'dart:io';

import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:music_player_frontend/core/audio_player/player_state.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';

class AudioProvider extends AbstractAudioProvider {
  bool hasBeenInitialized = false;

  AudioProvider(super.audioService, super.fileService) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          platform_service.MediaControl.skipToPrevious,
          platform_service.MediaControl.play,
          platform_service.MediaControl.pause,
          platform_service.MediaControl.skipToNext,
        ],
        systemActions: {platform_service.MediaAction.seek},
        playing: false,
      ),
    );
    init();
  }

  @override
  List<Song> get currentQueue => super.audioService.currentQueue;

  @override
  AudioSettings get currentAudioSettings =>
      super.audioService.settingsService.currentAudioSettings;

  @override
  Future<void> init() async {
    await super.audioService.updateCurrentSong();
    await super.audioService.initSettings();
    currentSong = super.audioService.currentSong;
    currentQueue = super.audioService.currentQueue;
    repeatNotifier.value = currentAudioSettings.repeat;
    shuffleNotifier.value = currentAudioSettings.shuffle;
    sliderNotifier.value = currentAudioSettings.slider;
    balanceNotifier.value = currentAudioSettings.balance;
    volumeNotifier.value = currentAudioSettings.volume;

    super.audioService.audioPlayer.onPositionChanged.listen((Duration event) {
      sliderNotifier.value = event.inMilliseconds;
      super.audioService.setSlider(event.inMilliseconds);
    });
    audioService.audioPlayer.onPlayerStateChanged.listen((state) {
      playingNotifier.value = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        skipToNext();
      }
    });
    changeMediaItem();
    notifyListeners();
  }

  @override
  Future<void> play() async {
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        controls: [platform_service.MediaControl.pause],
      ),
    );
    await super.audioService.play();
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        controls: [platform_service.MediaControl.play],
      ),
    );
    await super.audioService.pause();
  }

  @override
  Future<void> skipToNext() async {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [platform_service.MediaControl.skipToNext],
      ),
    );
    await super.audioService.skipToNext();
    currentSong = super.audioService.currentSong;
    changeMediaItem();
    notifyListeners();
  }

  @override
  Future<void> skipToPrevious() async {
    await super.audioService.skipToPrevious();
    currentSong = super.audioService.currentSong;
    changeMediaItem();
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

  @override
  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    super.audioService.setPlaybackSpeed(speed);
  }

  @override
  void setVolume(double volume) {
    volumeNotifier.value = volume;
    super.audioService.setVolume(volume);
  }

  @override
  void setBalance(double balance) {
    balanceNotifier.value = balance;
    super.audioService.setBalance(balance);
  }

  @override
  void setRepeat(bool repeat) {
    repeatNotifier.value = repeat;
    super.audioService.setRepeat(repeat);
  }

  @override
  void setShuffle(bool shuffle) {
    shuffleNotifier.value = shuffle;
    super.audioService.setShuffle(shuffle);
  }

  @override
  Future<void> setQueue(List<Song> songs) async {
    super.audioService.setQueue(songs);
    notifyListeners();
  }

  @override
  Future<Duration> getDuration() async {
    return await super.audioService.getDuration();
  }

  @override
  void addToQueue(Song song) {
    super.audioService.addToQueue(song);
    currentQueue = super.audioService.currentQueue;
    notifyListeners();
  }

  @override
  void addMultipleToQueue(List<Song> songs) {
    super.audioService.addMultipleToQueue(songs);
    currentQueue = super.audioService.currentQueue;
    notifyListeners();
  }

  @override
  void addNextToQueue(Song song) {
    super.audioService.addNextToQueue(song);
    currentQueue = super.audioService.currentQueue;
    notifyListeners();
  }

  @override
  void addMultipleNextToQueue(List<Song> songs) {
    super.audioService.addMultipleNextToQueue(songs);
    currentQueue = super.audioService.currentQueue;
    notifyListeners();
  }

  @override
  void removeFromQueue(Song song) {
    super.audioService.removeFromQueue(song);
    currentQueue = super.audioService.currentQueue;
    notifyListeners();
  }

  @override
  Future<void> setCurrentSong(Song song) async {
    await super.audioService.setCurrentSong(song);
    currentSong = song;
    changeMediaItem();
    notifyListeners();
  }

  @override
  void likeCurrentSong() {
    super.audioService.likeCurrentSong();
  }

  Future<void> changeMediaItem() async {
    File tempFile = await fileService.createWorkaroundFile(currentSong);
    platform_service.MediaItem item = platform_service.MediaItem(
      id: currentSong.id.toString(),
      album: currentSong.album.target?.name ?? 'Unknown Album',
      title: currentSong.name,
      artist: currentSong.artist.target?.name ?? 'Unknown Artist',
      duration: Duration(milliseconds: currentSong.duration),
      artUri: tempFile.uri,
    );
    mediaItem.add(item);
  }
}
