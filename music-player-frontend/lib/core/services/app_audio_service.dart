import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/played_song.dart';
import 'package:music_player_frontend/core/entities/queue_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/played_song_repo.dart';
import 'package:music_player_frontend/core/repository/queue_song_repo.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  final QueueSongRepository queueSongRepository;
  final PlayedSongRepository playedSongRepository;
  final AbstractAudioPlayer audioPlayer;
  final SongService songService;
  final SettingsService settingsService;

  AppAudioService(
    this.playedSongRepository,
    this.queueSongRepository,
    this.audioPlayer,
    this.songService,
    this.settingsService,
  ) {
    PlayedSong? lastPlayed = playedSongRepository.getMostRecentPlayedSong();
    if (lastPlayed != null && lastPlayed.song.target != null) {
      debugPrint(
        "Last played song: ${lastPlayed.song.target!.name}, duration: ${lastPlayed.duration}",
      );
      currentPlayedSong = lastPlayed;
    }
  }

  PlayedSong currentPlayedSong = PlayedSong();

  List<QueueSong> get queueSongs => queueSongRepository.getAllQueueSongs();

  List<Song> get queue =>
      queueSongs.map((e) => e.song.target).whereType<Song>().toList();

  List<Song> get shuffledQueue {
    List<Song> shuffled = List.from(queue);
    shuffled.shuffle();
    return shuffled;
  }

  List<Song> get currentQueue =>
      settingsService.currentAudioSettings.shuffle ? shuffledQueue : queue;

  int get currentIndexInNonShuffled =>
      currentQueue.isNotEmpty
          ? queue.indexOf(
            currentQueue[settingsService.currentAudioSettings.index],
          )
          : -1;

  Song get currentSong =>
      currentPlayedSong.song.target ??
      (currentQueue.isNotEmpty
          ? currentQueue[settingsService.currentAudioSettings.index]
          : Song());

  Song get nextSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(settingsService.currentAudioSettings.index + 1) %
              currentQueue.length]
          : Song();

  set currentSong(Song song) {
    int newIndex = currentQueue.indexOf(song);
    if (newIndex != -1) {
      settingsService.currentAudioSettings.index = newIndex;
      settingsService.updateAudioSettings();
    }
    if (song.id != currentPlayedSong.song.target?.id) {
      currentPlayedSong = PlayedSong();
    }
    currentPlayedSong.song.target = song;
    currentPlayedSong.playedAt = DateTime.now();
    playedSongRepository.savePlayedSong(currentPlayedSong);
  }

  Song get previousSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(settingsService.currentAudioSettings.index -
                  1 +
                  currentQueue.length) %
              currentQueue.length]
          : Song();

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
      audioPlayer.setSource(currentSong.path);
      seek(Duration.zero);
      play();
      return;
    }
    await playNext();
  }

  Future<void> playNext() async {
    if (queue.isEmpty) {
      return;
    }
    await setCurrentSong(nextSong);
    play();
  }

  Future<void> skipToPrevious() async {
    await setCurrentSong(previousSong);
    play();
  }

  Future<void> setCurrentSong(Song song) async {
    currentSong = song;
    audioPlayer.setSource(currentSong.path);
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
    settingsService.currentAudioSettings.index = currentQueue.indexOf(
      currentSong,
    );
    settingsService.updateAudioSettings();
  }

  void setSlider(int slider) {
    if (currentPlayedSong.song.target == null) {
      currentPlayedSong.song.target = currentSong;
    }
    currentPlayedSong.duration = slider;
    playedSongRepository.savePlayedSong(currentPlayedSong);
  }

  Future<void> initSettings() async {
    try {
      await audioPlayer.setSource(currentSong.path);
      await audioPlayer.seek(
        Duration(milliseconds: currentPlayedSong.duration),
      );
    } catch (e) {
      debugPrint("Error initializing audio player: $e");
    }
  }

  Future<Duration> getDuration() async {
    var duration = await audioPlayer.getDuration();
    debugPrint("Duration: $duration");
    if (duration == null) {
      return currentSong.duration > 0
          ? Duration(seconds: currentSong.duration)
          : Duration.zero;
    }
    if (currentSong.duration <= 0) {
      currentSong.duration = duration.inSeconds;
      songService.updateSong(currentSong);
    }
    return duration;
  }

  void addToQueue(Song song) {
    if (!queue.contains(song)) {
      QueueSong queueSong = QueueSong();
      queueSong.song.target = song;
      queueSong.position = 0.0 + queue.length;
      queueSongRepository.saveQueueSong(queueSong);
    }
  }

  void addMultipleToQueue(List<Song> songs) {
    for (var song in songs) {
      if (!queue.contains(song)) {
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position = 0.0 + queue.length;
        queueSongRepository.saveQueueSong(queueSong);
      }
    }
  }

  void addNextToQueue(Song song) {
    if (!queue.contains(song)) {
      int currentIndex = settingsService.currentAudioSettings.index;
      int nextIndex = (currentIndex + 1) % queue.length;
      if (nextIndex == 0) {
        nextIndex = queue.length;
        QueueSong queueSong = QueueSong();
        queueSong.song.target = song;
        queueSong.position = 0.0 + nextIndex;
        queueSongRepository.saveQueueSong(queueSong);
      } else {
        QueueSong currentQueueSong = queueSongs[currentIndex];
        QueueSong nextQueueSong = queueSongs[nextIndex];
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
    if (queue.contains(song)) {
      queueSongRepository.deleteSongFromQueue(song);
    }
  }

  void setQueue(List<Song> songs) async {
    if (queue.equals(songs)) {
      return;
    }
    queueSongRepository.clearQueue();
    queueSongRepository.saveAllQueueSongs(songs);
  }

  Future<List<Song>> getQueue() async {
    return queue;
  }

  void likeCurrentSong() {
    currentSong.liked = !currentSong.liked;
    songService.updateSong(currentSong);
  }
}
