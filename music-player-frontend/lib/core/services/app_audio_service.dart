import 'package:collection/collection.dart';
import 'package:music_player_frontend/core/entities/abstract/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/file_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  late final AbstractAudioPlayer _audioPlayer;
  AudioSettings audioSettings = AudioSettings();
  late final SettingsService _settingsService;
  late final SongService _songService;

  Song? currentSong;

  AppAudioService(this._settingsService, this._songService, this._audioPlayer) {
    audioSettings = _settingsService.getAudioSettings();
  }

  Future<void> play() async {
    debugPrint("play");
    await _audioPlayer.play();
  }

  Future<void> pause() async{
    debugPrint("pause");
    await _audioPlayer.pause();
  }

  Future<void> skipToNext() async {
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

  Future<void> setCurrentSong(String path) async {
    audioSettings.index = audioSettings.currentQueue.indexOf(path);
    _settingsService.updateAudioSettings(audioSettings);
    await updateCurrentSong();
  }

  Future<void> seek(Duration position) async {
    debugPrint("seek to $position");
    setSlider(position.inMilliseconds);
    _audioPlayer.seek(position);
  }

  void setVolume(double volume) {
    audioSettings.volume = volume;
    _audioPlayer.setVolume(volume);
    _settingsService.updateAudioSettings(audioSettings);
  }

  void setPlaybackSpeed(double speed) {
    _audioPlayer.setPlaybackSpeed(speed);
  }

  void setBalance(double balance) {
    audioSettings.balance = balance;
    _audioPlayer.setBalance(balance);
    _settingsService.updateAudioSettings(audioSettings);
  }

  void setRepeat(bool repeat) {
    audioSettings.repeat = repeat;
    _settingsService.updateAudioSettings(audioSettings);
  }

  void setShuffle(bool shuffle) {
    audioSettings.shuffle = shuffle;
    audioSettings.index = audioSettings.currentQueue.indexOf(
      currentSong?.path ?? audioSettings.queue[audioSettings.index]
    );
    _settingsService.updateAudioSettings(audioSettings);
  }

  void setSlider(int slider) {
    audioSettings.slider = slider;
    _settingsService.updateAudioSettings(audioSettings);
  }

  Future<void> initSettings() async {
    try {
      await _audioPlayer.setSource(audioSettings.currentSong ?? '',);
      await _audioPlayer.seek(
        Duration(milliseconds: audioSettings.slider),
      );
      debugPrint("Audio player: ${await _audioPlayer.getCurrentPosition()}");
    }
    catch (e) {
      debugPrint("Error initializing audio player: $e");
    }
  }

  Future<void> updateCurrentSong() async {
    if (audioSettings.queue.isEmpty) {
      debugPrint("Queue is empty, cannot update current song.");
      return;
    }
    String? path = audioSettings.currentSong;

    if (path == null) {
      debugPrint("Current song path is null, cannot update current song.");
      return;
    }

    currentSong = _songService.getSong(path);
    currentSong?.lastPlayed = DateTime.now();
    currentSong?.playCount += 1;
    debugPrint("Current song updated: ${currentSong?.name}, play count: ${currentSong?.playCount}");
    _songService.updateSong(currentSong!);
    // changeMediaItem();
  }

  // Future<void> changeMediaItem() async {
  //   File tempFile = await FileService.createWorkaroundFile(currentSong);
  //   if (Platform.isLinux) {
  //     MediaItem item = MediaItem(
  //         id: currentSong?.id.toString() ?? '-1',
  //         album: currentSong?.album.target?.name ?? 'Unknown Album',
  //         title: currentSong?.name ?? 'Unknown Song',
  //         artist: currentSong?.artist.target?.name ?? 'Unknown Artist',
  //         duration: Duration(milliseconds: currentSong?.duration ?? 0),
  //         artUri: tempFile.uri
  //     );
  //     mediaItem.add(item);
  //   }
  //   // else if (Platform.isWindows){
  //   //   AppAudioHandler.audioHandler.updateMetadata(
  //   //     MusicMetadata(
  //   //       title: song.title,
  //   //       album: song.album,
  //   //       albumArtist: song.albumArtist,
  //   //       artist: song.trackArtist,
  //   //     ),
  //   //   );
  //   // }
  // }

  Future<Duration> getDuration() async {
    var duration = await _audioPlayer.getDuration();
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
      _settingsService.updateAudioSettings(audioSettings);
    }
  }

  void addMultipleToQueue(List<String> songPaths) {
    for (String songPath in songPaths) {
      if (!audioSettings.queue.contains(songPath)) {
        audioSettings.queue.add(songPath);
        audioSettings.shuffledQueue.add(songPath);
      }
    }
    _settingsService.updateAudioSettings(audioSettings);
  }

  void addToQueueAtIndex(String songPath, int index) {
    if (!audioSettings.queue.contains(songPath)) {
      audioSettings.queue.insert(index, songPath);
      audioSettings.shuffledQueue.insert(index, songPath);
      _settingsService.updateAudioSettings(audioSettings);
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
    _settingsService.updateAudioSettings(audioSettings);
  }

  void removeFromQueue(String songPath) {
    if (audioSettings.queue.contains(songPath)) {
      audioSettings.queue.remove(songPath);
      audioSettings.shuffledQueue.remove(songPath);
      _settingsService.updateAudioSettings(audioSettings);

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
      Song? song = _songService.getSong(path);
      if (song != null) {
        queueSongs.add(song);
      } else {
        debugPrint("Song not found in service: $path");
        var metadata = await FileService.retrieveSong(path);
        song = Song();
        song.fromJson(metadata);
        _songService.songRepo.addSong(song);
        queueSongs.add(song);
      }
    }
    return queueSongs;
  }

}