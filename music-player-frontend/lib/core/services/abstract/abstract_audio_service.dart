import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  final AbstractAudioPlayer audioPlayer;
  final SongService songService;

  Song? currentSong;
  late AudioSettings audioSettings;

  AppAudioService(this.songService, this.audioPlayer);

  void init(AudioSettings settings) {
    audioSettings = settings;
  }

  Future<void> play() async {
    debugPrint("play");
    await audioPlayer.play();
  }

  Future<void> pause() async {
    debugPrint("pause");
    await audioPlayer.pause();
  }

  Future<void> skipToNext() async {
    if (audioSettings.repeat) {
      await seek(Duration.zero);
      play();
      return;
    }
    await playNext();
  }

  Future<void> playNext() async {
    if (audioSettings.queue.isEmpty) {
      debugPrint("Queue is empty, cannot play next.");
      return;
    }
    await setCurrentSong(audioSettings.nextSong);
    play();
  }

  Future<void> skipToPrevious() async {
    await setCurrentSong(audioSettings.previousSong);
  }

  Future<void> setCurrentSong(Song song) async {
    audioSettings.index = audioSettings.currentQueue.indexOf(song.path);
    currentSong = song;
    audioSettings.save();
    await updateCurrentSong();
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
    audioSettings.volume = volume;
    audioPlayer.setVolume(volume);
    audioSettings.save();
  }

  void setPlaybackSpeed(double speed) {
    audioPlayer.setPlaybackSpeed(speed);
  }

  void setBalance(double balance) {
    audioSettings.balance = balance;
    audioPlayer.setBalance(balance);
    audioSettings.save();
  }

  void setRepeat(bool repeat) {
    audioSettings.repeat = repeat;
    audioSettings.save();
  }

  void setShuffle(bool shuffle) {
    audioSettings.shuffle = shuffle;
    audioSettings.index = audioSettings.currentQueue.indexOf(
      currentSong?.path ?? audioSettings.queue[audioSettings.index],
    );
    audioSettings.save();
  }

  void setSlider(int slider) {
    audioSettings.slider = slider;
    audioSettings.save();
  }

  Future<void> initSettings() async {
    try {
      await audioPlayer.setSource(audioSettings.currentSong ?? '');
      await audioPlayer.seek(Duration(milliseconds: audioSettings.slider));
      debugPrint("Audio player: ${await audioPlayer.getCurrentPosition()}");
    } catch (e) {
      debugPrint("Error initializing audio player: $e");
    }
  }

  Future<void> updateCurrentSong() async {
    if (audioSettings.queue.isEmpty) {
      debugPrint("Queue is empty, cannot update current song.");
      return;
    }

    currentSong?.lastPlayed = DateTime.now();
    currentSong?.playCount += 1;
    debugPrint(
      "Current song updated: ${currentSong?.name}, play count: ${currentSong?.playCount}",
    );
    songService.updateSong(currentSong!);
  }

  Future<Duration> getDuration() async {
    var duration = await audioPlayer.getDuration();
    debugPrint("Duration: $duration");
    if (duration == null) {
      // debugPrint("Duration is null, using current song duration, ${currentSong.duration})");
      return currentSong != null && currentSong!.duration > 0
          ? Duration(seconds: currentSong!.duration)
          : Duration.zero;
    }
    if (currentSong != null && currentSong!.duration <= 0) {
      currentSong!.duration = duration.inSeconds;
    }
    return duration;
  }

  void addToQueue(String songPath) {
    if (!audioSettings.queue.contains(songPath)) {
      audioSettings.queue.add(songPath);
      audioSettings.shuffledQueue.add(songPath);
      audioSettings.save();
    }
  }

  void addMultipleToQueue(List<String> songPaths) {
    for (String songPath in songPaths) {
      if (!audioSettings.queue.contains(songPath)) {
        audioSettings.queue.add(songPath);
        audioSettings.shuffledQueue.add(songPath);
      }
    }
    audioSettings.save();
  }

  void addToQueueAtIndex(String songPath, int index) {
    if (!audioSettings.queue.contains(songPath)) {
      audioSettings.queue.insert(index, songPath);
      audioSettings.shuffledQueue.insert(index, songPath);
      audioSettings.save();
    }
  }

  void addMultipleToQueueAtIndex(List<String> songPaths, int index) {
    for (String songPath in songPaths) {
      if (!audioSettings.queue.contains(songPath)) {
        audioSettings.queue.insert(index, songPath);
        audioSettings.shuffledQueue.insert(index, songPath);
        index++;
      }
    }
    audioSettings.save();
  }

  void removeFromQueue(String songPath) {
    if (audioSettings.queue.contains(songPath)) {
      audioSettings.queue.remove(songPath);
      audioSettings.shuffledQueue.remove(songPath);
      audioSettings.save();
    }
  }

  void setQueue(List<String> songs) async {
    if (audioSettings.queue.equals(songs)) {
      return;
    }
    audioSettings.queue = List.from(songs);
    audioSettings.shuffledQueue = List.from(songs);
    audioSettings.shuffledQueue.shuffle();
  }

  Future<List<Song>> getQueue() async {
    List<Song> queueSongs = [];
    for (String path in audioSettings.queue) {
      Song? song = songService.getSong(path);
      if (song != null) {
        queueSongs.add(song);
      } else {
        debugPrint("Song not found in service: $path");
        song = await songService.addSong(path);
        queueSongs.add(song);
      }
    }
    return queueSongs;
  }
}
