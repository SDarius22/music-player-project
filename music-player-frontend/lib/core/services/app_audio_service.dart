import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
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
    _currentAudioSettings = settingsService.getAudioSettings();
    _currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _initPlayer();
  }

  Song _currentSong = Song();
  Playlist _queuePlaylist = Playlist();
  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  bool get shuffle => _currentAudioSettings.shuffle;

  Song getCurrentSong() {
    return _currentSong;
  }

  List<Song> get queue => _queuePlaylist.songsList;

  Future<void> play(Song song) async {
    debugPrint("play");
    if (song.path != _currentSong.path) {
      await setCurrentSongAndPlay(song);
    }
    await audioPlayer.play();
  }

  Future<void> pause() async {
    debugPrint("pause");
    await audioPlayer.pause();
  }

  Future<void> skipToNext(Song nextSong) async {
    await play(nextSong);
  }

  Future<void> skipToPrevious(Song previousSong) async {
    await play(previousSong);
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    debugPrint("Setting current song to ${song.path}");

    await audioPlayer.stop();

    _currentSong = song;
    _currentSong.lastPlayed = DateTime.now();
    _currentSong.playCount += 1;
    songService.updateSong(_currentSong);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();

    debugPrint("Loading song into audio player: ${song.path}");

    await audioPlayer.setFilePath(song.path);
    await audioPlayer.play();
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
    _currentAudioSettings.volume = volume;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setVolume(volume);
  }

  void setPlaybackSpeed(double speed) {
    _currentAudioSettings.speed = speed;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setSpeed(speed);
  }

  void setRepeat(bool repeat) {
    _currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  void setShuffle(bool shuffle) {
    _currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> _initPlayer() async {
    try {
      await audioPlayer.setVolume(_currentAudioSettings.volume);
      await audioPlayer.setFilePath(
        _currentSong.path,
        initialPosition: Duration(
          seconds: _currentAudioSettings.sliderInSeconds,
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
    playlistService.updateFavoritesPlaylist();
  }

  Future<void> updateSliderInSeconds(int seconds) async {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }
}
