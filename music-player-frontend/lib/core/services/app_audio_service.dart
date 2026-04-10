import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
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
  final AudioPlayer audioPlayer;
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;
  final AuthService authService;
  final PlaybackRestClient? playbackRestService;
  final ChunkService Function(String fileHash) createChunkManager;

  ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);

  void Function(String fileHash, String songName)? _onWebSongChange;

  void setWebSongChangeCallback(
    void Function(String fileHash, String songName) callback,
  ) {
    _onWebSongChange = callback;
  }

  bool _initialized = false;
  bool _isSwitchingSong = false;
  int _currentIndex = 0;
  final Completer<void> _initDone = Completer<void>();
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

  List<Song> get queue => _activeQueue;

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
    this.createChunkManager, {
    this.playbackRestService,
    AudioPlayer? audioPlayer,
  }) : audioPlayer = audioPlayer ?? AudioPlayer() {
    _currentAudioSettings = settingsService.getAudioSettings();
    currentSong = playlistService.getMostRecentPlayedSong();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _normalQueue = List.from(_queuePlaylist.getSongs());
    _initPlayer();

    this.audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
      }
    });

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (this.audioPlayer.playing) {
        pushStateToServer();
        unawaited(_proactivelyCachePrefixes());
      }
    });

    this.audioPlayer.errorStream.listen((error) {
      debugPrint("Audio Player Error: $error");
    });
  }

  Future<void> play() {
    debugPrint(
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

    debugPrint(
      '[AppAudioService] Starting _retryIfStuck: playing=${audioPlayer.playing}, isSwitching=$_isSwitchingSong, state=${audioPlayer.processingState}',
    );

    while (stuckMs < maxStuckMs) {
      await Future.delayed(checkInterval);

      if (!audioPlayer.playing || _isSwitchingSong) {
        debugPrint(
          '[_retryIfStuck] Early exit: playing=${audioPlayer.playing}, isSwitching=$_isSwitchingSong, state=${audioPlayer.processingState}',
        );
        return;
      }

      final state = audioPlayer.processingState;
      if (state == ProcessingState.loading ||
          state == ProcessingState.buffering) {
        debugPrint(
          '[AppAudioService] Detected loading/buffering state, resetting stuck timer',
        );
        prevPosition = null;
        continue;
      }

      final pos = audioPlayer.position;
      if (prevPosition != null && pos > prevPosition) return;
      if (prevPosition != null) stuckMs += checkInterval.inMilliseconds;
      prevPosition = pos;
      debugPrint(
        '[AppAudioService] Checking for stuck playback: position=$pos, prevPosition=$prevPosition, stuckMs=$stuckMs',
      );
    }

    if (!audioPlayer.playing || _isSwitchingSong || _normalQueue.isEmpty) {
      debugPrint(
        '[AppAudioService] Playback stuck but player is not playing or queue is empty, not retrying',
      );
      return;
    }
    debugPrint(
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
    pushStateToServer();
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

  void setRepeat(bool repeat) {
    _currentAudioSettings.repeat = repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
    audioPlayer.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
    pushStateToServer();
  }

  Future<void> setShuffle(bool shuffle) async {
    if (shuffle == _currentAudioSettings.shuffle) return;
    _currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings(_currentAudioSettings);
    final current = currentSong;
    final idx = _activeQueue.indexWhere((s) => s == current);
    _currentIndex = idx < 0 ? 0 : idx;
    pushStateToServer();
  }

  void _rebuildShuffledQueue({Song? prioritySong}) {
    _shuffledQueue = List.from(_normalQueue)..shuffle();
    if (prioritySong != null) {
      final idx = _shuffledQueue.indexWhere((s) => s == prioritySong);
      if (idx > 0) {
        _shuffledQueue.removeAt(idx);
        _shuffledQueue.insert(0, prioritySong);
      }
    }
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
    playlistService.addToPlaylist(_queuePlaylist, toAdd);
    pushStateToServer();
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    for (final song in songs.reversed) {
      if (_normalQueue.any((s) => s == song)) continue;

      final activeInsert = _activeQueue.isEmpty ? 0 : _currentIndex + 1;
      _activeQueue.insert(activeInsert, song);

      final other =
          _currentAudioSettings.shuffle ? _normalQueue : _shuffledQueue;
      final currentInOther = other.indexWhere((s) => s == currentSong);
      final otherInsert =
          currentInOther < 0 ? other.length : currentInOther + 1;
      other.insert(otherInsert, song);

      _queuePlaylist.addSong(song);
    }

    playlistService.updatePlaylist(_queuePlaylist);
    pushStateToServer();
  }

  Future<void> removeFromQueue(Song song) async {
    final activeIdx = _activeQueue.indexWhere((s) => s == song);
    if (activeIdx == -1) return;

    final wasCurrentSong = song == currentSong;
    _normalQueue.remove(song);
    _shuffledQueue.remove(song);
    playlistService.deleteFromPlaylist(song, _queuePlaylist);

    if (wasCurrentSong) {
      if (_activeQueue.isNotEmpty) {
        _currentIndex = _currentIndex.clamp(0, _activeQueue.length - 1);
        await _loadIndex(_currentIndex);
        await play();
      }
    } else if (activeIdx < _currentIndex) {
      _currentIndex--;
    }
    pushStateToServer();
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty) return;

    if (!songs.equals(_normalQueue)) {
      debugPrint("updating queue with new songs");
      _normalQueue.clear();
      _normalQueue.addAll(songs);
      _queuePlaylist.clearSongs();
      playlistService.addToPlaylist(_queuePlaylist, _normalQueue);
      _rebuildShuffledQueue(prioritySong: song);
    }

    await setCurrentSongAndPlay(song);
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSong = song;
    try {
      final idx = _activeQueue.indexWhere((s) => s == song);
      _currentIndex = idx < 0 ? 0 : idx;
      await _loadIndex(_currentIndex);
      await play();
    } catch (e) {
      debugPrint("Error setting current song and playing: $e");
    }
  }

  Future<void> _initPlayer() async {
    if (_initialized) return;
    _initialized = true;

    await audioPlayer.setVolume(_currentAudioSettings.volume);
    await audioPlayer.setSpeed(_currentAudioSettings.speed);
    await audioPlayer.setLoopMode(
      _currentAudioSettings.repeat ? LoopMode.one : LoopMode.off,
    );

    if (_normalQueue.isNotEmpty) {
      _rebuildShuffledQueue(prioritySong: currentSong);
      final idx = _activeQueue.indexWhere((s) => s == currentSong);
      _currentIndex = idx < 0 ? 0 : idx;
      await _loadIndex(
        _currentIndex,
        position: _currentAudioSettings.sliderInSeconds,
      );
    }

    if (!_initDone.isCompleted) _initDone.complete();
  }

  Future<void> _onSongCompleted() async {
    debugPrint(
      '[_onSongCompleted] called: queue=${_activeQueue.length}, isSwitching=$_isSwitchingSong, index=$_currentIndex',
    );
    if (_activeQueue.isEmpty || _isSwitchingSong) return;
    _currentIndex = (_currentIndex + 1) % _activeQueue.length;
    await _loadIndex(_currentIndex);
    await play();
    unawaited(songService.syncLibraryMetadata());
  }

  Future<void> _loadIndex(int idx, {int? position}) async {
    debugPrint('[AppAudioService] _loadAndPlayIndex($idx) called');
    if (_activeQueue.isEmpty) return;
    _isSwitchingSong = true;
    await _initDone.future;
    _finalizePlayDuration();

    try {
      final outgoing = currentSong;
      if (outgoing == null) {
        debugPrint(
          '[AppAudioService] No outgoing song to finalize before switching',
        );
        return;
      }

      if (!outgoing.isLocal() && outgoing.getHash().isNotEmpty) {
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
      pushStateToServer();
    } finally {
      _isSwitchingSong = false;
    }
  }

  AudioSource _buildAudioSource(Song song) {
    final bool isServerTrack = !song.isLocal();
    debugPrint(
      "Building audio source for song ${song.getName()} (isLocal: ${song.isLocal})",
    );

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
            ChunkStatsService.instance.report,
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
        debugPrint(
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

  void pushStateToServer() {
    if (playbackRestService == null) return;
    final queueFileHashes =
        _normalQueue
            .where((s) => !s.isLocal() && s.getHash().isNotEmpty)
            .map((s) => s.getHash())
            .toList();
    final currentFileHash =
        currentSong != null &&
                !currentSong!.isLocal() &&
                currentSong!.getHash().isNotEmpty
            ? currentSong!.getHash()
            : null;
    final dto = PlaybackStateDto(
      queueFileHashes: queueFileHashes,
      currentFileHash: currentFileHash,
      positionMs: audioPlayer.position.inMilliseconds,
      shuffle: _currentAudioSettings.shuffle,
      repeat: _currentAudioSettings.repeat,
    );
    playbackRestService!.savePlaybackState(dto);
  }

  Future<void> restoreFromServerState(PlaybackStateDto dto) async {
    if (dto.queueFileHashes.isEmpty) return;

    final resolvedQueue =
        (await Future.wait(
          dto.queueFileHashes.map(
            (hash) => songService.fetchSongByFileHash(hash),
          ),
        )).whereType<Song>().toList();

    if (resolvedQueue.isEmpty) return;

    _currentAudioSettings.shuffle = dto.shuffle;
    _currentAudioSettings.repeat = dto.repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
    await audioPlayer.setLoopMode(dto.repeat ? LoopMode.one : LoopMode.off);

    _normalQueue.clear();
    _normalQueue.addAll(resolvedQueue);
    _queuePlaylist.clearSongs();
    playlistService.addToPlaylist(_queuePlaylist, _normalQueue);

    Song current = resolvedQueue.first;
    if (dto.currentFileHash != null) {
      final matches = resolvedQueue.where(
        (s) => s.getHash() == dto.currentFileHash,
      );
      if (matches.isNotEmpty) current = matches.first;
    }
    _rebuildShuffledQueue(prioritySong: current);
    final idx = _activeQueue.indexWhere((s) => s == current);
    _currentIndex = idx < 0 ? 0 : idx;
    currentSong = current;

    await _initDone.future;
    await audioPlayer.setAudioSource(
      _buildAudioSource(current),
      initialPosition: Duration(milliseconds: dto.positionMs),
    );
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
      if (song.isLocal() || song.getHash().isEmpty) continue;
      unawaited(_prefetchSongFraction(song, _nextSongTargets[i] * progress));
    }

    for (int i = 0; i < _prevSongTargets.length; i++) {
      final songIdx = (_currentIndex - i - 1 + q.length) % q.length;
      if (songIdx == _currentIndex) continue;
      final song = q[songIdx];
      if (song.isLocal() || song.getHash().isEmpty) continue;
      unawaited(_prefetchSongFraction(song, _prevSongTargets[i] * progress));
    }
  }

  Future<void> _prefetchSongFraction(Song song, double fraction) async {
    if (fraction <= 0) return;
    try {
      final manager = createChunkManager(song.getHash());
      if (!manager.isReady) await manager.loadManifest();
      final targetCount = max(1, (manager.totalChunks * fraction).round());
      for (int i = 0; i < targetCount; i++) {
        await manager.prefetchChunk(i);
      }
    } catch (e) {
      debugPrint('[prefetch] ${song.getName()}: $e');
    }
  }

  void likeCurrentSong() {
    currentSongNotifier.value?.likedByUser =
        !currentSongNotifier.value!.likedByUser;
    likedNotifier.value = currentSongNotifier.value!.likedByUser;
    songService.updateSong(currentSongNotifier.value!);
    playlistService.updateFavoritesPlaylist();
  }

  void _onSongStarted(Song song) {
    song.lastPlayed = DateTime.now();
    song.playCount += 1;
    song.pendingPlayCountDelta += 1;
    song.requiresSync = true;
    _playStartTime = DateTime.now();
    songService.updateSong(song);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();
    _proactivelyCachePrefixes();

    if (song.isLocal()) {
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
    song.pendingPlayDurationSeconds += elapsed;
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
