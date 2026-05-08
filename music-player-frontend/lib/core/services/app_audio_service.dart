import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/models/chunk_delivery_stats.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/core/services/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/local_libs/extensions.dart';
import 'package:universal_platform/universal_platform.dart';

class AppAudioService {
  static final _logger = Logger('AppAudioService');

  AudioPlayer _audioPlayer;

  AudioPlayer get audioPlayer => _audioPlayer;
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;
  final AuthService authService;
  final PlaybackRestClient playbackRestService;
  final ChunkService Function(String fileHash) createChunkManager;

  ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> playerInstanceVersion = ValueNotifier<int>(0);

  void Function(String fileHash, String songName)? _onWebSongChange;

  void setWebSongChangeCallback(
    void Function(String fileHash, String songName) callback,
  ) {
    _onWebSongChange = callback;
  }

  bool _initialized = false;
  bool _isSwitchingSong = false;
  int _currentIndex = 0;
  Timer? _positionSaveTimer;
  DateTime? _playStartTime;
  StreamSubscription<ProcessingState>? _processingStateSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;

  List<Song> _normalQueue = [];
  List<Song> _shuffledQueue = [];
  late Playlist _queuePlaylist;

  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  List<Song> get _activeQueue =>
      _currentAudioSettings.shuffle ? _shuffledQueue : _normalQueue;

  List<Song> get queue => _normalQueue;

  int get currentIndex => _currentIndex;

  Song? get currentSong => currentSongNotifier.value;

  set currentSong(Song? song) {
    currentSongNotifier.value = song;
    likedNotifier.value = song?.likedByUser ?? false;
  }

  AppAudioService(
    this.songService,
    this.settingsService,
    this.playlistService,
    this.authService,
    this.createChunkManager,
    this.playbackRestService, {
    AudioPlayer? audioPlayer,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer();

  Future<void> initializeAppAudio() async {
    if (_initialized) return;
    _initialized = true;
    _currentAudioSettings = await settingsService.getAudioSettings();
    currentSong = await playlistService.getMostRecentPlayedSong();
    _queuePlaylist = await playlistService.getPlaylistByName("Queue");
    _normalQueue = List.from(_queuePlaylist.getSongs());
    await _initPlayer();

    _attachPlayerListeners();

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (audioPlayer.playing) {
        settingsService.updateAudioSettings(_currentAudioSettings);
        unawaited(_proactivelyCachePrefixes());
      }
    });
  }

  void _attachPlayerListeners() {
    _processingStateSubscription = audioPlayer.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });

    _errorSubscription = audioPlayer.errorStream.listen((error) {
      _logger.severe("Audio Player Error: $error");
      unawaited(_recoverFromPlayerError());
    });
  }

  bool _isRecoveringFromError = false;
  DateTime? _lastRecoveryAt;
  int _consecutiveRecoveryCount = 0;
  static const int _maxConsecutiveRecoveries = 3;

  Future<void> _recoverFromPlayerError() async {
    if (_isRecoveringFromError) return;
    if (_isSwitchingSong) return;
    if (_activeQueue.isEmpty) return;
    _isRecoveringFromError = true;
    try {
      final now = DateTime.now();
      if (_lastRecoveryAt != null &&
          now.difference(_lastRecoveryAt!) < const Duration(seconds: 5)) {
        _consecutiveRecoveryCount++;
      } else {
        _consecutiveRecoveryCount = 1;
      }
      _lastRecoveryAt = now;

      if (_consecutiveRecoveryCount > _maxConsecutiveRecoveries) {
        _logger.severe(
          '[AppAudioService] Player error recovered ${_consecutiveRecoveryCount - 1} times '
          'in a row without progress; skipping to next song',
        );
        _consecutiveRecoveryCount = 0;
        await skipToNext();
        return;
      }

      final pos = audioPlayer.position;
      final rewindSeconds =
          (pos.inMilliseconds - 1000).clamp(0, 1 << 30) ~/ 1000;
      _logger.warning(
        '[AppAudioService] Recovering from player error: rewinding to ${rewindSeconds}s with a fresh AudioPlayer instance',
      );

      await _processingStateSubscription?.cancel();
      _processingStateSubscription = null;
      await _errorSubscription?.cancel();
      _errorSubscription = null;
      try {
        await _audioPlayer.dispose();
      } catch (e) {
        _logger.fine('[AppAudioService] Old player dispose threw: $e');
      }

      _audioPlayer = AudioPlayer();
      _attachPlayerListeners();
      playerInstanceVersion.value++;

      await _audioPlayer.setVolume(_currentAudioSettings.volume);
      await _audioPlayer.setSpeed(_currentAudioSettings.speed);
      await _audioPlayer.setLoopMode(
        _currentAudioSettings.repeat ? LoopMode.one : LoopMode.off,
      );

      await _loadIndex(_currentIndex, position: rewindSeconds);
      await play();
    } catch (e, st) {
      _logger.severe('[AppAudioService] Player recovery failed: $e\n$st');
    } finally {
      _isRecoveringFromError = false;
    }
  }

  Future<void> play() {
    _logger.fine(
      '[AppAudioService] play() called: playing=${audioPlayer.playing}, state=${audioPlayer.processingState}',
    );
    _playStartTime ??= DateTime.now();
    final future = audioPlayer.play();
    unawaited(_retryIfStuck());
    return future;
  }

  Future<void> _retryIfStuck() async {
    const checkInterval = Duration(milliseconds: 500);
    const maxStuckMs = 1000;
    int stuckMs = 0;
    Duration? prevPosition;

    _logger.fine(
      '[AppAudioService] Starting _retryIfStuck: playing=${audioPlayer.playing}, isSwitching=$_isSwitchingSong, state=${audioPlayer.processingState}',
    );

    while (stuckMs < maxStuckMs) {
      await Future.delayed(checkInterval);

      if (!audioPlayer.playing || _isSwitchingSong) {
        _logger.fine(
          '[_retryIfStuck] Early exit: playing=${audioPlayer.playing}, isSwitching=$_isSwitchingSong, state=${audioPlayer.processingState}',
        );
        return;
      }

      final state = audioPlayer.processingState;
      if (state == ProcessingState.loading ||
          state == ProcessingState.buffering) {
        _logger.fine(
          '[AppAudioService] Detected loading/buffering state, resetting stuck timer',
        );
        prevPosition = null;
        continue;
      }

      final pos = audioPlayer.position;
      if (prevPosition != null && pos > prevPosition) return;
      if (prevPosition != null) stuckMs += checkInterval.inMilliseconds;
      prevPosition = pos;
      _logger.fine(
        '[AppAudioService] Checking for stuck playback: position=$pos, prevPosition=$prevPosition, stuckMs=$stuckMs',
      );
    }

    if (!audioPlayer.playing || _isSwitchingSong || _normalQueue.isEmpty) {
      _logger.fine(
        '[AppAudioService] Playback stuck but player is not playing or queue is empty, not retrying',
      );
      return;
    }
    _logger.fine(
      '[AppAudioService] Playback stuck for ${maxStuckMs}ms, retrying',
    );
    await _loadIndex(_currentIndex);
    await play();
  }

  Future<void> pause() {
    _finalizePlayDuration();
    return audioPlayer.pause();
  }

  Future<void> skipToNext() async {
    if (_activeQueue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _activeQueue.length;
    await _loadIndex(_currentIndex);
    await play();
  }

  Future<void> skipToPrevious() async {
    if (_activeQueue.isEmpty) return;
    _currentIndex =
        _currentIndex > 0 ? _currentIndex - 1 : _activeQueue.length - 1;
    await _loadIndex(_currentIndex);
    await play();
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

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

  Future<void> setRepeat(bool repeat) async {
    _currentAudioSettings.repeat = repeat;
    await settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
  }

  Future<void> setShuffle(bool shuffle) async {
    if (shuffle == _currentAudioSettings.shuffle) return;
    final current = currentSong;
    _currentAudioSettings.shuffle = shuffle;
    if (shuffle) {
      _rebuildShuffledQueue();
    }
    final idx = _activeQueue.indexWhere((s) => s == current);
    _currentIndex = idx < 0 ? 0 : idx;
    await settingsService.updateAudioSettings(_currentAudioSettings);
  }

  void _rebuildShuffledQueue() {
    _shuffledQueue = List.from(_normalQueue)..shuffle();
  }

  Future<Duration> getDuration() async {
    final duration = audioPlayer.duration;
    final currentSongDuration = currentSong?.durationInSeconds ?? 0;
    if (duration == null || duration.inSeconds <= 0) {
      return Duration(seconds: currentSongDuration);
    }
    if (currentSongDuration <= 0 && currentSong != null) {
      currentSong!.durationInSeconds = duration.inSeconds;
      songService.updateSong(currentSong!);
    }
    return duration;
  }

  Future<void> addToQueue(List<Song> songs) async {
    final existingHashes = _normalQueue.map((s) => s.getHash()).toSet();
    final toAdd =
        songs.where((s) => !existingHashes.contains(s.getHash())).toList();
    if (toAdd.isEmpty) return;

    _normalQueue.addAll(toAdd);
    _shuffledQueue.addAll(toAdd);
    _queuePlaylist = await playlistService.addToPlaylist(_queuePlaylist, toAdd);
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    for (final song in songs.reversed) {
      if (_normalQueue.any((s) => s == song)) continue;
      final currentInNormal = _normalQueue.indexWhere((s) => s == currentSong);
      final normalInsert =
          currentInNormal < 0 ? _normalQueue.length : currentInNormal + 1;
      _normalQueue.insert(normalInsert, song);

      final currentInShuffled = _shuffledQueue.indexWhere(
        (s) => s == currentSong,
      );
      final shuffledInsert =
          currentInShuffled < 0 ? _shuffledQueue.length : currentInShuffled + 1;
      _shuffledQueue.insert(shuffledInsert, song);

      _queuePlaylist.insertSongAt(song, normalInsert);
    }

    await playlistService.updatePlaylist(_queuePlaylist);
  }

  Future<void> removeFromQueue(Song song) async {
    final activeIdx = _activeQueue.indexWhere((s) => s == song);
    if (activeIdx == -1) return;

    final wasCurrentSong = song == currentSong;
    _normalQueue.remove(song);
    _shuffledQueue.remove(song);
    await playlistService.deleteFromPlaylist(song, _queuePlaylist);

    if (wasCurrentSong) {
      if (_activeQueue.isNotEmpty) {
        _currentIndex = _currentIndex.clamp(0, _activeQueue.length - 1);
        await _loadIndex(_currentIndex);
        await play();
      }
    } else if (activeIdx < _currentIndex) {
      _currentIndex--;
    }
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty) return;

    var loadedSong = await songService.fullyFetchSong(song);

    if (!songs.equals(_normalQueue)) {
      _logger.fine("updating queue with new songs");
      _normalQueue.clear();
      _normalQueue.addAll(songs);
      _queuePlaylist.clearSongs();
      _queuePlaylist = await playlistService.addToPlaylist(
        _queuePlaylist,
        _normalQueue,
      );
      _rebuildShuffledQueue();
    }

    await setCurrentSongAndPlay(loadedSong);
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSong = song;
    try {
      final idx = _activeQueue.indexWhere((s) => s == song);
      _currentIndex = idx < 0 ? 0 : idx;
      await _loadIndex(_currentIndex);
      await play();
    } catch (e) {
      _logger.severe("Error setting current song and playing: $e");
    }
  }

  Future<void> _initPlayer() async {
    await audioPlayer.setVolume(_currentAudioSettings.volume);
    await audioPlayer.setSpeed(_currentAudioSettings.speed);
    await audioPlayer.setLoopMode(
      _currentAudioSettings.repeat ? LoopMode.one : LoopMode.off,
    );

    if (_normalQueue.isNotEmpty) {
      _rebuildShuffledQueue();
      final idx = _activeQueue.indexWhere((s) => s == currentSong);
      _currentIndex = idx < 0 ? 0 : idx;
      await _loadIndex(
        _currentIndex,
        position: _currentAudioSettings.sliderInSeconds,
      );
    }
  }

  Future<void> _onSongCompleted() async {
    _logger.fine(
      '[_onSongCompleted] called: queue=${_activeQueue.length}, isSwitching=$_isSwitchingSong, index=$_currentIndex',
    );
    if (_activeQueue.isEmpty || _isSwitchingSong) return;
    _currentIndex = (_currentIndex + 1) % _activeQueue.length;
    await _loadIndex(_currentIndex);
    await play();
  }

  Future<void> _loadIndex(int idx, {int? position}) async {
    _logger.fine('[AppAudioService] _loadAndPlayIndex($idx) called');
    if (_activeQueue.isEmpty) return;
    _isSwitchingSong = true;
    _finalizePlayDuration();
    _logger.fine(
      '[AppAudioService] Loading song at index $idx: ${_activeQueue[idx].getName()}',
    );

    try {
      final outgoing = currentSong;
      if (outgoing != null &&
          !outgoing.isLocal &&
          outgoing.getHash().isNotEmpty) {
        createChunkManager(outgoing.getHash()).flushStats();
      }

      final song = _activeQueue[idx];
      currentSong = song;
      if (!UniversalPlatform.isDesktop) {
        await audioPlayer.stop();
      }
      await audioPlayer.setAudioSource(
        _buildAudioSource(song),
        initialPosition: Duration(seconds: position ?? 0),
      );
      _onSongStarted(song);
    } finally {
      _isSwitchingSong = false;
    }
  }

  AudioSource _buildAudioSource(Song song) {
    final bool isServerTrack = !song.isLocal;

    if (isServerTrack) {
      if (UniversalPlatform.isWeb) {
        _onWebSongChange?.call(song.getHash(), song.getName());
        return AudioSource.uri(
          Uri.parse('/music-player/p2p-stream/${song.getHash()}'),
          tag: Map<String, dynamic>.from({
            "path": song.path,
            "fileHash": song.getHash(),
            "song": song,
          }),
        );
      }

      return P2PChunkedAudioSource(
        fileHash: song.getHash(),
        chunkManagerFactory: (hash) {
          final manager = createChunkManager(hash);
          manager.configureSongInfo(
            song.getName(),
            ChunkStatsService.instance.reportSilently,
          );
          return manager;
        },
        tag: Map<String, dynamic>.from({
          "path": song.path,
          "fileHash": song.getHash(),
          "song": song,
        }),
      );
    } else {
      if (song.path == null || song.path!.isEmpty) {
        _logger.warning(
          "Warning: Song ${song.getName()} is marked as local but has no path",
        );
      }
      return AudioSource.uri(
        Uri.file(song.path!),
        tag: Map<String, dynamic>.from({
          "path": song.path,
          "fileHash": song.getHash(),
          "song": song,
        }),
      );
    }
  }

  static const _nextSongTargets = [0.25, 0.20, 0.15, 0.10, 0.05];
  static const _prevSongTargets = [0.10, 0.05];

  Future<void> _proactivelyCachePrefixes() async {
    if (_normalQueue.isEmpty) return;

    final totalSecs =
        audioPlayer.duration?.inSeconds.toDouble() ??
        currentSong?.durationInSeconds.toDouble() ??
        0.0;
    final posSecs = audioPlayer.position.inSeconds.toDouble();
    final progress =
        totalSecs > 0 ? (posSecs / totalSecs).clamp(0.0, 1.0) : 0.0;

    final q = _activeQueue;
    for (int i = 0; i < _nextSongTargets.length; i++) {
      final songIdx = (_currentIndex + i + 1) % q.length;
      if (songIdx == _currentIndex) continue;
      final song = q[songIdx];
      if (song.isLocal || song.getHash().isEmpty) continue;
      unawaited(_prefetchSongFraction(song, _nextSongTargets[i] * progress));
    }

    for (int i = 0; i < _prevSongTargets.length; i++) {
      final songIdx = (_currentIndex - i - 1 + q.length) % q.length;
      if (songIdx == _currentIndex) continue;
      final song = q[songIdx];
      if (song.isLocal || song.getHash().isEmpty) continue;
      unawaited(_prefetchSongFraction(song, _prevSongTargets[i] * progress));
    }
  }

  Future<void> _prefetchSongFraction(Song song, double fraction) async {
    if (fraction <= 0) return;
    try {
      final manager = createChunkManager(song.getHash());
      manager.configureSongInfo(
        song.getName(),
        ChunkStatsService.instance.reportSilently,
      );
      if (!manager.isReady) await manager.loadManifest();
      final targetCount = max(1, (manager.totalChunks * fraction).round());
      for (int i = 0; i < targetCount; i++) {
        await manager.prefetchChunk(i);
      }
    } catch (e) {
      _logger.warning('[prefetch] ${song.getName()}: $e');
    }
  }

  Future<void> likeCurrentSong() async {
    currentSongNotifier.value?.likedByUser =
        !currentSongNotifier.value!.likedByUser;
    likedNotifier.value = currentSongNotifier.value!.likedByUser;
    await songService.updateSong(currentSongNotifier.value!);
  }

  void _onSongStarted(Song song) {
    song.lastPlayed = DateTime.now();
    song.playCount += 1;
    _playStartTime = DateTime.now();
    songService.updateSong(song);
    _proactivelyCachePrefixes();

    if (song.isLocal) {
      ChunkStatsService.instance.report(
        ChunkDeliveryStats(
          fileHash: song.getHash(),
          songName: song.getName(),
          localChunks: 1,
        ),
      );
    }
  }

  void _finalizePlayDuration() {
    if (_playStartTime == null) return;
    final elapsed = DateTime.now().difference(_playStartTime!).inSeconds;
    _playStartTime = null;
    if (elapsed <= 0) return;
    final song = currentSong;
    if (song!.getHash().isEmpty && song.path!.isEmpty) return;
    songService.updateSong(song);
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> dispose() async {
    _positionSaveTimer?.cancel();
    await _processingStateSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _errorSubscription?.cancel();
    await audioPlayer.dispose();
  }
}
