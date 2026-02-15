import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

class AppAudioService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;

  AppAudioService(
    this.songService,
    this.settingsService,
    this.playlistService,
  ) {
    _currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getPlaylist(1)!;

    _initPlayer();
  }

  Song _currentSong = Song();
  Playlist _queuePlaylist = Playlist();

  bool get shuffle => settingsService.currentAudioSettings.shuffle;

  Song getCurrentSong() {
    return _currentSong;
  }

  List<Song> get queue => _queuePlaylist.songsList;

  Future<void> play(Song song) async {
    debugPrint("play");
    if (song.path != _currentSong.path) {
      await setCurrentSong(song);
    }
    await audioPlayer.play();
  }

  Future<void> pause() async {
    debugPrint("pause");
    await audioPlayer.pause();
  }

  Future<void> skipToNext(Song nextSong) async {
    if (settingsService.currentAudioSettings.repeat) {
      audioPlayer.setUrl(_currentSong.path);
      seek(Duration.zero);
      play(_currentSong);
      return;
    }
    await _playNext(nextSong);
  }

  Future<void> _playNext(Song nextSong) async {
    if (queue.isEmpty) {
      return;
    }
    await play(nextSong);
  }

  Future<void> skipToPrevious(Song previousSong) async {
    await play(previousSong);
  }

  Future<void> setCurrentSong(Song song) async {
    _currentSong = song;
    _currentSong.lastPlayed = DateTime.now();
    _currentSong.playCount += 1;

    debugPrint("Setting current song to ${song.path}");

    await audioPlayer.setUrl(song.path);

    songService.updateSong(_currentSong);
  }

  Future<void> seek(Duration position) async {
    debugPrint("seek to $position");
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
    audioPlayer.setSpeed(speed);
  }

  void setRepeat(bool repeat) {
    settingsService.currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings();
  }

  void setShuffle(bool shuffle) {
    settingsService.currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings();
  }

  Future<void> _initPlayer() async {
    try {
      await audioPlayer.setVolume(settingsService.currentAudioSettings.volume);
      await audioPlayer.setUrl(
        _currentSong.path,
        initialPosition: Duration(
          seconds: settingsService.currentAudioSettings.sliderInSeconds,
        ),
      );
      await audioPlayer.seek(
        Duration(milliseconds: _currentSong.durationInSeconds),
      );
    } catch (e) {
      debugPrint("Error initializing audio player: $e");
    }
  }

  Future<Duration> getDuration() async {
    var duration = audioPlayer.duration;
    debugPrint("Duration: $duration");
    if (duration == null || duration.inSeconds <= 0) {
      return _currentSong.durationInSeconds > 0
          ? Duration(seconds: _currentSong.durationInSeconds)
          : Duration.zero;
    }
    if (_currentSong.durationInSeconds <= 0) {
      _currentSong.durationInSeconds = duration.inSeconds;
    }
    return duration;
  }

  void addToQueue(List<Song> songs) {
    playlistService.addToPlaylist(_queuePlaylist, songs);
  }

  void addNextToQueue(List<Song> songs) {
    bool changesMade = false;
    for (Song song in songs.reversed) {
      if (!queue.contains(song)) {
        changesMade = true;
        _queuePlaylist.songs.add(song);

        int currentIndex = queue.indexOf(_currentSong);
        int nextIndex = (currentIndex + 1) % queue.length;
        if (nextIndex == 0) {
          _queuePlaylist.songsIds.add(song.id);
        } else {
          _queuePlaylist.songsIds.insert(nextIndex, song.id);
        }
      }
    }
    if (changesMade) {
      playlistService.updatePlaylist(_queuePlaylist);
    }
  }

  void removeFromQueue(Song song) {
    if (queue.contains(song)) {
      playlistService.deleteFromPlaylist(song, _queuePlaylist);
    }
  }

  void setQueue(List<Song> songs) async {
    if (queue.equals(songs)) {
      debugPrint("Queue is the same, not updating.");
      return;
    }
    _queuePlaylist.songs.clear();
    _queuePlaylist.songsIds.clear();
    addToQueue(songs);
  }

  void likeCurrentSong() {
    _currentSong.likedByUser = !_currentSong.likedByUser;
    songService.updateSong(_currentSong);
  }

  Future<void> updateSliderInSeconds(int seconds) async {
    settingsService.currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings();
  }
}
