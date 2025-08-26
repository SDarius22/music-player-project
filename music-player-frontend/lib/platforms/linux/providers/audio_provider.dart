import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/audio_player/player_state.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/platforms/linux/audio_player/system_audio_handler.dart';

class AudioProvider extends AbstractAudioProvider {
  bool hasBeenInitialized = false;
  late Future queueFuture;

  Song get currentSong => super.audioService.currentSong ?? Song();

  @override
  Future<void> init(
    SettingsService settingsService,
    SongService songService,
    AbstractAudioPlayer audioPlayer,
  ) async {
    if (!hasBeenInitialized) {
      var audioService = AppAudioService(songService, audioPlayer);
      audioService.init(settingsService.getAudioSettings());
      var audioHandler = await platform_service.AudioService.init(
        builder: () => SystemAudioHandler(audioService),
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
        skipToNext();
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
  void setQueue(List<String> songs) {
    super.audioService.setQueue(songs);
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  Future<Duration> getDuration() async {
    return await super.audioService.getDuration();
  }

  @override
  void addToQueue(String songPath) {
    super.audioService.addToQueue(songPath);
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  void addMultipleToQueue(List<String> songPaths) {
    super.audioService.addMultipleToQueue(songPaths);
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  void addNextToQueue(String songPath) {
    super.audioService.addToQueueAtIndex(
      songPath,
      super.audioService.audioSettings.currentQueue.indexOf(
            audioService.currentSong?.path,
          ) +
          1,
    );
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  void addMultipleNextToQueue(List<String> songPaths) {
    super.audioService.addMultipleToQueueAtIndex(
      songPaths,
      super.audioService.audioSettings.currentQueue.indexOf(
            audioService.currentSong?.path,
          ) +
          1,
    );
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  void removeFromQueue(String songPath) {
    super.audioService.removeFromQueue(songPath);
    queueFuture = Future(() => super.audioService.getQueue());
    notifyListeners();
  }

  @override
  Future<void> setCurrentSong(Song song) async {
    await super.audioService.setCurrentSong(song);
    notifyListeners();
  }
}
