import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/entities/played_song.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/playlist_song.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  final AbstractAudioPlayer audioPlayer;
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;

  AppAudioService(
    this.audioPlayer,
    this.songService,
    this.settingsService,
    this.playlistService,
  ) {
    PlayedSong? lastPlayed = playlistService.getMostRecentPlayedSong();
    if (lastPlayed != null && lastPlayed.song.target != null) {
      debugPrint(
        "Last played song: ${lastPlayed.song.target!.name}, duration: ${lastPlayed.duration}",
      );
      _currentPlayedSong = lastPlayed;
      _queuePlaylist = playlistService.getPlaylist(1)!;
    }
  }

  PlayedSong _currentPlayedSong = PlayedSong();
  Playlist _queuePlaylist = Playlist();

  List<PlaylistSong> get _queueSongs =>
      _queuePlaylist.playlistSongs
          .sorted((a, b) => a.position.compareTo(b.position))
          .toList();

  late List<Song> queue = _queueSongs.map((e) => e.song.target!).toList();

  late List<Song> shuffledQueue = List.from(queue)..shuffle();

  late Song _currentSong = _currentPlayedSong.song.target ?? Song();

  List<Song> get currentQueue =>
      settingsService.currentAudioSettings.shuffle ? shuffledQueue : queue;

  int get currentIndexInNonShuffled =>
      currentQueue.isNotEmpty ? queue.indexOf(currentSong) : -1;

  int get currentIndex => currentQueue.indexOf(currentSong);

  Song get currentSong => _currentSong;

  Song get nextSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(currentIndexInNonShuffled + 1) % currentQueue.length]
          : Song();

  set currentSong(Song song) {
    _currentSong = song;
    if (song.id != _currentPlayedSong.song.target?.id) {
      _currentPlayedSong = PlayedSong();
    }
    _currentPlayedSong.song.target = song;
    _currentPlayedSong.playedAt = DateTime.now();
    playlistService.savePlayedSong(_currentPlayedSong);
  }

  Song get previousSong =>
      currentQueue.isNotEmpty
          ? currentQueue[(currentIndexInNonShuffled - 1 + currentQueue.length) %
              currentQueue.length]
          : Song();

  void refreshQueue() {
    queue = _queueSongs.map((e) => e.song.target!).toList();
    shuffledQueue = List.from(queue)..shuffle();
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
    settingsService.updateAudioSettings();
  }

  void setSlider(int slider) {
    _currentPlayedSong.song.target ??= currentSong;
    _currentPlayedSong.duration = slider;
    playlistService.savePlayedSong(_currentPlayedSong);
  }

  Future<void> initSettings() async {
    try {
      await audioPlayer.setSource(currentSong.path);
      await audioPlayer.seek(
        Duration(milliseconds: _currentPlayedSong.duration),
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
    }
    return duration;
  }

  void addToQueue(Song song) {
    if (!queue.contains(song)) {
      playlistService.addToPlaylist(_queuePlaylist, [song]);
      refreshQueue();
    }
  }

  void addMultipleToQueue(List<Song> songs) {
    for (var song in songs) {
      if (!queue.contains(song)) {
        addToQueue(song);
      }
    }
  }

  void addNextToQueue(Song song) {
    if (!queue.contains(song)) {
      int currentIndex = currentIndexInNonShuffled;
      int nextIndex = (currentIndex + 1) % queue.length;
      if (nextIndex == 0) {
        nextIndex = queue.length;
        PlaylistSong queueSong = PlaylistSong();
        queueSong.playlist.targetId = 1;
        queueSong.song.target = song;
        queueSong.position = 0.0 + nextIndex;
        playlistService.savePlaylistSong(queueSong);
      } else {
        PlaylistSong currentQueueSong = _queueSongs[currentIndex];
        PlaylistSong nextQueueSong = _queueSongs[nextIndex];
        PlaylistSong queueSong = PlaylistSong();
        queueSong.playlist.targetId = 1;
        queueSong.song.target = song;
        queueSong.position =
            (currentQueueSong.position + nextQueueSong.position) / 2;
        playlistService.savePlaylistSong(queueSong);
      }
      playlistService.updatePlaylist(_queuePlaylist);
      refreshQueue();
    }
  }

  void addMultipleNextToQueue(List<Song> songs) {
    for (Song song in songs.reversed) {
      addNextToQueue(song);
    }
  }

  void removeFromQueue(Song song) {
    if (queue.contains(song)) {
      playlistService.deleteFromPlaylist(song, _queuePlaylist);
      refreshQueue();
    }
  }

  void setQueue(List<Song> songs) async {
    if (queue.equals(songs)) {
      debugPrint("Queue is the same, not updating.");
      return;
    }
    playlistService.deleteAllSongsFromPlaylist(_queuePlaylist);
    addMultipleToQueue(songs);
  }

  void likeCurrentSong() {
    // Implement liking functionality here
  }
}
