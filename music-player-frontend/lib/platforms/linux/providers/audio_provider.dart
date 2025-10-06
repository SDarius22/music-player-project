import 'package:audio_service/audio_service.dart' as platform_service;
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/audio_player/player_state.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/repository/queue_song_repo.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/platforms/linux/audio_player/system_audio_handler.dart';

class AudioProvider extends AbstractAudioProvider {
  bool hasBeenInitialized = false;

  @override
  Song get currentSong =>
      super.audioService.settingsService.currentAudioSettings.currentSong;

  @override
  List<Song> get currentQueue =>
      super.audioService.settingsService.currentAudioSettings.currentQueue;

  @override
  AudioSettings get currentAudioSettings =>
      super.audioService.settingsService.currentAudioSettings;

  @override
  Future<void> init(
    QueueSongRepository queueSongRepository,
    SettingsService settingsService,
    SongService songService,
    AbstractAudioPlayer audioPlayer,
  ) async {
    if (!hasBeenInitialized) {
      var audioService = AppAudioService(
        queueSongRepository,
        audioPlayer,
        songService,
        settingsService,
      );
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
    repeatNotifier.value = currentAudioSettings.repeat;
    shuffleNotifier.value = currentAudioSettings.shuffle;
    sliderNotifier.value = currentAudioSettings.slider;
    balanceNotifier.value = currentAudioSettings.balance;
    volumeNotifier.value = currentAudioSettings.volume;

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
  void setQueue(List<Song> songs) {
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
    notifyListeners();
  }

  @override
  void addMultipleToQueue(List<Song> songs) {
    super.audioService.addMultipleToQueue(songs);
    notifyListeners();
  }

  @override
  void addNextToQueue(Song song) {
    super.audioService.addNextToQueue(song);
    notifyListeners();
  }

  @override
  void addMultipleNextToQueue(List<Song> songs) {
    super.audioService.addMultipleNextToQueue(songs);
    notifyListeners();
  }

  @override
  void removeFromQueue(Song song) {
    super.audioService.removeFromQueue(song);
    notifyListeners();
  }

  @override
  Future<void> setCurrentSong(Song song) async {
    await super.audioService.setCurrentSong(song);
    notifyListeners();
  }

  @override
  void likeCurrentSong() {
    super.audioService.likeCurrentSong();
  }
}
