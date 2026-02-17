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

  List<Song> _normalQueue = [];
  List<Song> _shuffledQueue = [];
  Song _currentSong = Song();
  Playlist _queuePlaylist = Playlist();
  AudioSettings _currentAudioSettings = AudioSettings();
  bool _reloadingQueue = false;

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  /// Returns the active queue based on shuffle setting
  List<Song> get queue =>
      _currentAudioSettings.shuffle ? _shuffledQueue : _normalQueue;

  List<Song> get oppositeQueue =>
      _currentAudioSettings.shuffle ? _normalQueue : _shuffledQueue;

  Song get currentSong => _currentSong;

  AppAudioService(
    this.songService,
    this.settingsService,
    this.playlistService,
  ) {
    _currentAudioSettings = settingsService.getAudioSettings();
    _currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _normalQueue = _queuePlaylist.songsList;
    _shuffledQueue = List.from(_normalQueue)..shuffle();
    _initPlayer();
  }

  void updateCurrentSong(Song updated) {
    if (updated.path != _currentSong.path) return;

    _currentSong = updated;
    _currentSong.lastPlayed = DateTime.now();
    _currentSong.playCount += 1;

    songService.updateSong(_currentSong);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();
  }

  int _indexInActiveQueue(String path) =>
      queue.indexWhere((s) => s.path == path);

  int _indexInNormalQueue(String path) =>
      _normalQueue.indexWhere((s) => s.path == path);

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
    if (song.path.isEmpty) return;

    if (_indexInNormalQueue(song.path) == -1) {
      await addToQueue([song]);
    }

    _currentSong = song;

    while (_reloadingQueue) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final playIndex = _indexInActiveQueue(song.path);
    if (playIndex >= 0) {
      await audioPlayer.seek(Duration.zero, index: playIndex);
      await audioPlayer.play();
    } else {
      await audioPlayer.setFilePath(song.path);
      await audioPlayer.play();
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

  void setRepeat(bool repeat) {
    _currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setLoopMode(repeat ? LoopMode.one : LoopMode.all);
  }

  Future<void> setShuffle(bool shuffle) async {
    if (_currentAudioSettings.shuffle == shuffle) return;

    _currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings(_currentAudioSettings);

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: audioPlayer.position,
      autoplay: audioPlayer.playing,
    );
  }

  Future<void> _initPlayer() async {
    await audioPlayer.setVolume(_currentAudioSettings.volume);
    await audioPlayer.setSpeed(_currentAudioSettings.speed);
    await audioPlayer.setLoopMode(
      _currentAudioSettings.repeat ? LoopMode.one : LoopMode.all,
    );

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: Duration(seconds: _currentAudioSettings.sliderInSeconds),
    );
  }

  Future<void> _reloadPlayerQueue({
    Song? initialSong,
    Duration? initialPosition,
    bool autoplay = false,
  }) async {
    if (_reloadingQueue) return;
    _reloadingQueue = true;

    try {
      final sources =
          queue
              .where((s) => s.path.isNotEmpty)
              .map((s) => AudioSource.file(s.path))
              .toList();

      if (sources.isEmpty) {
        await audioPlayer.stop();
        return;
      }

      var initialIndex = 0;
      if (initialSong != null && initialSong.path.isNotEmpty) {
        final idx = queue.indexWhere((s) => s.path == initialSong.path);
        if (idx >= 0) initialIndex = idx;
      }

      await audioPlayer.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );

      if (autoplay) await audioPlayer.play();
    } finally {
      _reloadingQueue = false;
    }
  }

  Future<Duration> getDuration() async {
    final duration = audioPlayer.duration;
    if (duration == null || duration.inSeconds <= 0) {
      return Duration(seconds: _currentSong.durationInSeconds);
    }
    if (_currentSong.durationInSeconds <= 0) {
      _currentSong.durationInSeconds = duration.inSeconds;
      songService.updateSong(_currentSong);
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

    playlistService.addToPlaylist(_queuePlaylist, toAdd);
    _normalQueue = _queuePlaylist.songsList;
    _shuffledQueue.addAll(toAdd);

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: audioPlayer.position,
    );
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    final currentIndexNormal = _indexInNormalQueue(_currentSong.path);
    var insertAt =
        currentIndexNormal >= 0 ? currentIndexNormal + 1 : _normalQueue.length;
    final existingPaths = _normalQueue.map((s) => s.path).toSet();

    final currentIndexShuffled = _shuffledQueue.indexWhere(
      (s) => s.path == _currentSong.path,
    );
    var shuffleInsertAt =
        currentIndexShuffled >= 0
            ? currentIndexShuffled + 1
            : _shuffledQueue.length;

    for (final song in songs) {
      if (song.path.isEmpty || existingPaths.contains(song.path)) continue;
      existingPaths.add(song.path);
      _queuePlaylist.songs.add(song);
      _queuePlaylist.songsIds.insert(insertAt++, song.id);
      _shuffledQueue.insert(shuffleInsertAt++, song);
    }

    playlistService.updatePlaylist(_queuePlaylist);
    _normalQueue = _queuePlaylist.songsList;

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: audioPlayer.position,
    );
  }

  Future<void> removeFromQueue(Song song) async {
    if (_indexInNormalQueue(song.path) == -1) return;

    playlistService.deleteFromPlaylist(song, _queuePlaylist);
    _normalQueue = _queuePlaylist.songsList;
    _shuffledQueue.removeWhere((s) => s.path == song.path);

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: audioPlayer.position,
      autoplay: audioPlayer.playing,
    );
  }

  Future<void> setQueue(List<Song> songs) async {
    final currentPaths = _normalQueue.map((s) => s.path).toList();
    final newPaths = songs.map((s) => s.path).toList();
    if (_listsEqual(currentPaths, newPaths)) return;

    _queuePlaylist.songs.clear();
    _queuePlaylist.songsIds.clear();
    playlistService.addToPlaylist(_queuePlaylist, songs);
    _normalQueue = List.from(songs);
    _shuffledQueue = List.from(_normalQueue)..shuffle();

    await _reloadPlayerQueue(
      initialSong: _currentSong,
      initialPosition: audioPlayer.position,
    );
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void likeCurrentSong() {
    _currentSong.likedByUser = !_currentSong.likedByUser;
    songService.updateSong(_currentSong);
    playlistService.updateFavoritesPlaylist();
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }
}
