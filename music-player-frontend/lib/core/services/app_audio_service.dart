import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/queue_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/queue_song_repo.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  final QueueSongRepository queueSongRepository;
  final AbstractAudioPlayer audioPlayer;
  final SongService songService;
  final SettingsService settingsService;

  AppAudioService(
    this.queueSongRepository,
    this.audioPlayer,
    this.songService,
    this.settingsService,
  );

  Future<void> play() async {
    debugPrint("play");
    await audioPlayer.play();
  }

  Future<void> pause() async {
    debugPrint("pause");
    await audioPlayer.pause();
  }

  Future<void> skipToNext() async {
    if (settingsService.currentAudioSettings.repeat) {
      audioPlayer.setSource(
        settingsService.currentAudioSettings.currentSong.path,
      );
      seek(Duration.zero);
      debugPrint("Replaying current song due to repeat being enabled.");
      play();
      return;
    }
    await playNext();
  }

  Future<void> playNext() async {
    if (settingsService.currentAudioSettings.queue.isEmpty) {
      debugPrint("Queue is empty, cannot play next.");
      return;
    }
    await setCurrentSong(settingsService.currentAudioSettings.nextSong);
    play();
  }

  Future<void> skipToPrevious() async {
    await setCurrentSong(settingsService.currentAudioSettings.previousSong);
    play();
  }

  Future<void> setCurrentSong(Song song) async {
    settingsService.currentAudioSettings.currentSong = song;
    settingsService.updateAudioSettings();
    audioPlayer.setSource(
      settingsService.currentAudioSettings.currentSong.path,
    );
    updateCurrentSong();
  }

  Future<void> seek(Duration position) async {
    debugPrint("seek to $position");
    setSlider(position.inMilliseconds);
    audioPlayer.seek(position);
  }

  Future<void> stop() async {
    debugPrint("stop");
    await audioPlayer.stop();
  }

  void setVolume(double volume) {
    settingsService.currentAudioSettings.volume = volume;
    settingsService.updateAudioSettings();
    audioPlayer.setVolume(volume);
  }

  void setPlaybackSpeed(double speed) {
    audioPlayer.setPlaybackSpeed(speed);
  }

  void setBalance(double balance) {
    settingsService.currentAudioSettings.balance = balance;
    settingsService.updateAudioSettings();
    audioPlayer.setBalance(balance);
  }

  void setRepeat(bool repeat) {
    settingsService.currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings();
  }

  void setShuffle(bool shuffle) {
    settingsService.currentAudioSettings.shuffle = shuffle;
    settingsService.currentAudioSettings.index = settingsService
        .currentAudioSettings
        .currentQueue
        .indexOf(settingsService.currentAudioSettings.currentSong);
    settingsService.updateAudioSettings();
  }

  void setSlider(int slider) {
    settingsService.currentAudioSettings.slider = slider;
    settingsService.updateAudioSettings();
  }

  Future<void> initSettings() async {
    try {
      audioPlayer.setSource(
        settingsService.currentAudioSettings.currentSong.path,
      );
      audioPlayer.seek(
        Duration(milliseconds: settingsService.currentAudioSettings.slider),
      );
      debugPrint("Audio player: ${await audioPlayer.getCurrentPosition()}");
    } catch (e) {
      debugPrint("Error initializing audio player: $e");
    }
  }

  Future<void> updateCurrentSong() async {
    if (settingsService.currentAudioSettings.queue.isEmpty) {
      debugPrint("Queue is empty, cannot update current song.");
      return;
    }
    songService.updateSongPlayed(
      settingsService.currentAudioSettings.currentSong,
    );
    // currentSong?.image = metadata['image'] as Uint8List?;
    // currentSong?.lastPlayed = DateTime.now();
    // currentSong?.playCount += 1;
    // debugPrint(
    //   "Current song updated: ${currentSong?.name}, play count: ${currentSong?.playCount}",
    // );
    // try {
    //   songService.updateSong(currentSong!);
    // } catch (e) {
    //   debugPrint("Error updating song in service: $e");
    // }
  }

  Future<Duration> getDuration() async {
    var duration = await audioPlayer.getDuration();
    debugPrint("Duration: $duration");
    if (duration == null) {
      // debugPrint("Duration is null, using current song duration, ${currentSong.duration})");
      return settingsService.currentAudioSettings.currentSong.duration > 0
          ? Duration(
            seconds: settingsService.currentAudioSettings.currentSong.duration,
          )
          : Duration.zero;
    }
    if (settingsService.currentAudioSettings.currentSong.duration <= 0) {
      settingsService.currentAudioSettings.currentSong.duration =
          duration.inSeconds;
      songService.updateSong(settingsService.currentAudioSettings.currentSong);
    }
    return duration;
  }

  void addToQueue(Song song) {
    if (!settingsService.currentAudioSettings.queue.contains(song)) {
      QueueSong queueSong = QueueSong();
      queueSong.song.target = song;
      queueSong.position =
          0.0 + settingsService.currentAudioSettings.queue.length;
      queueSongRepository.saveQueueSong(queueSong);
    }
  }

  void addMultipleToQueue(List<Song> songs) {
    for (var song in songs) {
      if (!settingsService.currentAudioSettings.queue.contains(song)) {
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position =
            0.0 + settingsService.currentAudioSettings.queue.length;
        queueSongRepository.saveQueueSong(queueSong);
      }
    }
  }

  void addNextToQueue(Song song) {
    if (!settingsService.currentAudioSettings.queue.contains(song)) {
      int currentIndex = settingsService.currentAudioSettings.index;
      int nextIndex =
          (currentIndex + 1) %
          settingsService.currentAudioSettings.queue.length;
      if (nextIndex == 0) {
        nextIndex = settingsService.currentAudioSettings.queue.length;
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position = 0.0 + nextIndex;
        queueSongRepository.saveQueueSong(queueSong);
      } else {
        QueueSong currentQueueSong =
            settingsService.currentAudioSettings.queueSongs[currentIndex];
        QueueSong nextQueueSong =
            settingsService.currentAudioSettings.queueSongs[nextIndex];
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position =
            (currentQueueSong.position + nextQueueSong.position) / 2;
        queueSongRepository.saveQueueSong(queueSong);
      }
    }
  }

  void addMultipleNextToQueue(List<Song> songs) {
    for (Song song in songs.reversed) {
      addNextToQueue(song);
    }
  }

  void removeFromQueue(Song song) {
    if (settingsService.currentAudioSettings.queue.contains(song)) {
      queueSongRepository.deleteSongFromQueue(song);
    }
  }

  void setQueue(List<Song> songs) async {
    if (settingsService.currentAudioSettings.queue.equals(songs)) {
      return;
    }
    queueSongRepository.clearQueue();
    queueSongRepository.saveAllQueueSongs(songs);
  }

  Future<List<Song>> getQueue() async {
    return settingsService.currentAudioSettings.queue;
  }

  void likeCurrentSong() {
    settingsService.currentAudioSettings.currentSong.liked =
        !settingsService.currentAudioSettings.currentSong.liked;
    songService.updateSong(settingsService.currentAudioSettings.currentSong);
  }
}
