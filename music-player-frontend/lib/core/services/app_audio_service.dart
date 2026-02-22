import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/local_libs/extensions.dart';

class AppAudioService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;

  ValueNotifier<Song> currentSongNotifier = ValueNotifier<Song>(Song());
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);

  bool _initialized = false;
  List<Song> _normalQueue = [];
  Playlist _queuePlaylist = Playlist();
  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  List<Song> get queue => _normalQueue;

  Song get currentSong => currentSongNotifier.value;

  set currentSong(Song song) {
    currentSongNotifier.value = song;
    likedNotifier.value = song.likedByUser;
  }

  AppAudioService(
    this.songService,
    this.settingsService,
    this.playlistService,
  ) {
    _currentAudioSettings = settingsService.getAudioSettings();
    currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _normalQueue = _queuePlaylist.songsList;
    _initPlayer();
  }

  Future<void> play() => audioPlayer.play();

  Future<void> pause() => audioPlayer.pause();

  Future<void> skipToNext() async {
    await audioPlayer.seekToNext();
    await audioPlayer.play();
  }

  Future<void> skipToPrevious() async {
    await audioPlayer.seekToPrevious();
    await audioPlayer.play();
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSong = song;
    try {
      await audioPlayer.seek(Duration.zero, index: _getPlayIndex(song));
      await audioPlayer.play();
    } catch (e) {
      debugPrint("Error setting current song and playing: $e");
    }
  }

  Future<void> seek(Duration position) => audioPlayer.seek(position);

  Future<void> stop() => audioPlayer.stop();

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

  void setPitch(double pitch) {
    _currentAudioSettings.pitch = pitch;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setPitch(pitch);
  }

  void setRepeat(bool repeat) {
    _currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setLoopMode(repeat ? LoopMode.one : LoopMode.all);
  }

  Future<void> setShuffle(bool shuffle) async {
    if (shuffle == _currentAudioSettings.shuffle) return;

    _currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings(_currentAudioSettings);

    await audioPlayer.setShuffleModeEnabled(shuffle);
  }

  Future<Duration> getDuration() async {
    final duration = audioPlayer.duration;
    if (duration == null || duration.inSeconds <= 0) {
      return Duration(seconds: currentSong.durationInSeconds);
    }
    if (currentSong.durationInSeconds <= 0) {
      currentSong.durationInSeconds = duration.inSeconds;
      songService.updateSong(currentSong);
    }
    return duration;
  }

  Future<void> addToQueue(List<Song> songs) async {
    final existingPaths = _normalQueue.map((s) => s.path).toSet();
    final toAdd =
        songs
            .where((s) => s.path.isNotEmpty && !existingPaths.contains(s.path))
            .toList();
    if (toAdd.isEmpty) return;

    _normalQueue.addAll(toAdd);
    playlistService.addToPlaylist(_queuePlaylist, toAdd);

    await audioPlayer.addAudioSources(
      toAdd.map((song) => AudioSource.file(song.path)).toList(),
    );
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    final currentIndexNormal = _normalQueue.indexOf(currentSong);
    var insertAt =
        currentIndexNormal >= 0 ? currentIndexNormal + 1 : _normalQueue.length;

    for (final song in songs.reversed) {
      if (song.path.isEmpty || _normalQueue.contains(song)) continue;
      _normalQueue.insert(insertAt, song);

      _queuePlaylist.songs.add(song);
      _queuePlaylist.songsIds.insert(insertAt, song.id);
    }

    playlistService.updatePlaylist(_queuePlaylist);

    await audioPlayer.insertAudioSources(
      insertAt,
      songs.map((song) => AudioSource.file(song.path)).toList(),
    );
  }

  Future<void> removeFromQueue(Song song) async {
    if (!_normalQueue.contains(song)) return;

    _normalQueue.remove(song);

    playlistService.deleteFromPlaylist(song, _queuePlaylist);

    var audioSources = audioPlayer.audioSources;
    await audioPlayer.removeAudioSourceAt(
      audioSources.indexWhere((source) {
        if (source is ProgressiveAudioSource) {
          debugPrint("Comparing ${source.uri.toFilePath()} with ${song.path}");
          return source.uri.toFilePath() == song.path;
        }
        return false;
      }),
    );
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty || songs.equals(_normalQueue)) {
      await setCurrentSongAndPlay(song);
      return;
    }

    _normalQueue = List.from(songs);

    _queuePlaylist.songs.clear();
    _queuePlaylist.songsIds.clear();
    playlistService.addToPlaylist(_queuePlaylist, songs);

    await _setAudioSourcesForQueue(song);
    await setCurrentSongAndPlay(song);
  }

  Future<void> _initPlayer() async {
    if (_initialized) return;
    _initialized = true;
    await audioPlayer.setVolume(_currentAudioSettings.volume);
    await audioPlayer.setSpeed(_currentAudioSettings.speed);
    await audioPlayer.setLoopMode(
      _currentAudioSettings.repeat ? LoopMode.one : LoopMode.all,
    );

    await _setAudioSourcesForQueue(currentSong);

    audioPlayer.sequenceStateStream.listen((state) {
      final currentSource = state.currentSource;
      if (currentSource is! ProgressiveAudioSource) return;

      final path = currentSource.uri.toFilePath();

      final song = _normalQueue.firstWhere(
        (s) => s.path == path,
        orElse: () {
          debugPrint("No song found in queue for path: $path");
          throw Exception("No song found in queue for path: $path");
        },
      );
      if (song.path.isEmpty) return;
      _updateCurrentSong(song);
    });
  }

  int _getPlayIndex(Song song) {
    final playIndex = audioPlayer.audioSources.indexWhere((source) {
      if (source is ProgressiveAudioSource) {
        return source.uri.toFilePath() == song.path;
      }
      return false;
    });
    return playIndex != -1 ? playIndex : 0;
  }

  Future<void> _setAudioSourcesForQueue(Song song) async {
    if (_normalQueue.isEmpty) return;

    await audioPlayer.setAudioSources(
      queue.map((song) => AudioSource.file(song.path)).toList(),
    );
    if (_currentAudioSettings.shuffle) {
      audioPlayer.setShuffleModeEnabled(true);
    }

    int initialIndex = _getPlayIndex(song);

    if (initialIndex != -1) {
      await audioPlayer.seek(
        Duration(seconds: _currentAudioSettings.sliderInSeconds),
        index: initialIndex,
      );
    }
  }

  void likeCurrentSong() {
    currentSongNotifier.value.likedByUser =
        !currentSongNotifier.value.likedByUser;
    likedNotifier.value = currentSongNotifier.value.likedByUser;
    songService.updateSong(currentSongNotifier.value);
    playlistService.updateFavoritesPlaylist();
  }

  void _updateCurrentSong(Song updated) {
    if (updated.path == currentSong.path) return;

    currentSong = updated;

    currentSongNotifier.value.lastPlayed = DateTime.now();
    currentSongNotifier.value.playCount += 1;

    songService.updateSong(currentSong);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
  }
}
