// coverage:ignore-file

import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/entities/playback_source_selection.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/core/p2p/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/extensions/list_extensions.dart';
import 'package:universal_platform/universal_platform.dart';

class AppAudioService {
  static final _logger = Logger('AppAudioService');

  static const _sessionRestoreTimeout = Duration(seconds: 10);

  AudioPlayer _audioPlayer;

  AudioPlayer get audioPlayer => _audioPlayer;
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;
  final AuthService authService;
  final PlaybackRestClient playbackRestService;
  final ChunkService Function(String fileHash) createChunkManager;
  final AudioPlayer Function() _createAudioPlayer;

  ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> playerInstanceVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> queueMutationNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> songPeerCountNotifier = ValueNotifier<int>(0);

  void Function(String fileHash, String songName)? _onWebSongChange;
  Future<bool> Function()? _onBeforeWebPlayback;
  bool _useWebServiceWorkerStream = true;

  void setWebSongChangeCallback(
    void Function(String fileHash, String songName) callback,
  ) {
    _onWebSongChange = callback;
  }

  void setWebPlaybackReadyCallback(Future<bool> Function() callback) {
    _onBeforeWebPlayback = callback;
  }

  bool _initialized = false;
  bool _isSwitchingSong = false;
  bool _stuckCheckActive = false;
  bool _autoPlayFetchInProgress = false;
  bool _autoPlayTailFetchArmed = true;
  int _currentIndex = 0;
  int _loadRequestVersion = 0;
  Future<void> _sourceInstallTail = Future<void>.value();
  String? _activeSourceIntent;
  PlaybackSourceSelection? _activePlaybackSource;
  Timer? _positionSaveTimer;
  DateTime? _playStartTime;
  DateTime? _ttfaRequestedAt;
  bool _ttfaLoadingSeen = false;

  double? lastTimeToFirstAudioMs;
  StreamSubscription<ProcessingState>? _processingStateSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  ValueNotifier<int>? _boundPeerStateNotifier;
  VoidCallback? _boundPeerStateListener;

  List<Song> _normalQueue = [];
  List<Song> _shuffledQueue = [];
  late Playlist _queuePlaylist;

  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  List<Song> get _activeQueue =>
      _currentAudioSettings.shuffle ? _shuffledQueue : _normalQueue;

  List<Song> get queue => List.unmodifiable(_activeQueue);

  List<Song> get normalQueue => List.unmodifiable(_normalQueue);

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
    AudioPlayer Function()? createAudioPlayer,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer(),
       _createAudioPlayer = createAudioPlayer ?? AudioPlayer.new;

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
      if (_ttfaRequestedAt != null &&
          (state == ProcessingState.loading ||
              state == ProcessingState.buffering)) {
        _ttfaLoadingSeen = true;
      }
    });

    _playerStateSubscription = audioPlayer.playerStateStream.listen((state) {
      final requestedAt = _ttfaRequestedAt;
      if (requestedAt != null &&
          _ttfaLoadingSeen &&
          state.playing &&
          state.processingState == ProcessingState.ready) {
        final ms =
            DateTime.now().difference(requestedAt).inMicroseconds / 1000.0;
        _ttfaRequestedAt = null;
        lastTimeToFirstAudioMs = ms;
        _logger.info(
          '[METRIC] ttfa_ms=${ms.toStringAsFixed(1)} '
          'song=${currentSong?.getName()}',
        );
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
      final resumeSeconds = pos.inSeconds;
      _rejectActiveLocalSource();
      _logger.warning(
        '[AppAudioService] Recovering from player error at ${resumeSeconds}s with a fresh AudioPlayer instance',
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

      _audioPlayer = _createAudioPlayer();
      _attachPlayerListeners();
      playerInstanceVersion.value++;

      await _audioPlayer.setVolume(_currentAudioSettings.volume);
      await _audioPlayer.setSpeed(_currentAudioSettings.speed);
      await _audioPlayer.setLoopMode(
        _currentAudioSettings.repeat ? LoopMode.one : LoopMode.off,
      );

      if (!await _loadIndex(_currentIndex, position: resumeSeconds)) return;
      await play();
    } catch (e, st) {
      _logger.severe('[AppAudioService] Player recovery failed: $e\n$st');
    } finally {
      _isRecoveringFromError = false;
    }
  }

  Future<void> play() async {
    _logger.fine(
      '[AppAudioService] play() called: playing=${audioPlayer.playing}, state=${audioPlayer.processingState}',
    );
    if (audioPlayer.processingState == ProcessingState.idle &&
        _activeQueue.isNotEmpty) {
      if (!await _loadIndex(
        _currentIndex,
        position: _currentAudioSettings.sliderInSeconds,
      )) {
        return;
      }
    }
    _playStartTime ??= DateTime.now();
    final future = audioPlayer.play();
    if (!UniversalPlatform.isWeb) {
      unawaited(_retryIfStuck());
    }
    return future;
  }

  Future<void> _retryIfStuck() async {
    if (_stuckCheckActive) return;
    _stuckCheckActive = true;
    try {
      await _runStuckCheck();
    } finally {
      _stuckCheckActive = false;
    }
  }

  Future<void> _runStuckCheck() async {
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
    final resumeSeconds = (prevPosition ?? audioPlayer.position).inSeconds;
    _logger.fine(
      '[AppAudioService] Playback stuck for ${maxStuckMs}ms, retrying from ${resumeSeconds}s',
    );
    if (!await _loadIndex(_currentIndex, position: resumeSeconds)) return;
    await play();
  }

  Future<void> pause() {
    _finalizePlayDuration();
    return audioPlayer.pause();
  }

  Future<void> skipToNext() async {
    if (_activeQueue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _activeQueue.length;
    if (!await _loadIndex(_currentIndex)) return;
    await play();
  }

  Future<void> skipToPrevious() async {
    if (_activeQueue.isEmpty) return;
    _currentIndex =
        _currentIndex > 0 ? _currentIndex - 1 : _activeQueue.length - 1;
    if (!await _loadIndex(_currentIndex)) return;
    await play();
  }

  Future<void> seek(Duration position) async {
    await audioPlayer.seek(position);
  }

  Future<void> stop() => audioPlayer.stop();

  Future<void> resetSession() async {
    _invalidateLoadRequests();
    _playStartTime = null;
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
    await _processingStateSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _errorSubscription?.cancel();
    _processingStateSubscription = null;
    _playerStateSubscription = null;
    _positionSubscription = null;
    _errorSubscription = null;
    if (_boundPeerStateNotifier != null && _boundPeerStateListener != null) {
      _boundPeerStateNotifier!.removeListener(_boundPeerStateListener!);
    }
    _boundPeerStateNotifier = null;
    _boundPeerStateListener = null;
    await audioPlayer.stop();
    _normalQueue.clear();
    _shuffledQueue.clear();
    _currentIndex = 0;
    _currentAudioSettings = AudioSettings();
    currentSong = null;
    songPeerCountNotifier.value = 0;
    _initialized = false;
    _notifyQueueMutation();
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
      _rebuildShuffledQueue(firstSong: current);
    }
    final idx = _activeQueue.indexWhere((s) => s == current);
    _currentIndex = idx < 0 ? 0 : idx;
    _notifyQueueMutation();
    await settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> setAutoPlay(bool autoPlay) async {
    if (autoPlay == _currentAudioSettings.autoPlay) return;
    _currentAudioSettings.autoPlay = autoPlay;
    await settingsService.updateAudioSettings(_currentAudioSettings);
    if (autoPlay) {
      unawaited(_maybeExtendQueueForAutoPlay());
    }
  }

  int getCurrentSongPeerCount() {
    final song = currentSong;
    if (song == null || song.hasLocalFile || song.getHash().isEmpty) return 0;
    return createChunkManager(song.getHash()).availablePeerCount;
  }

  void _rebuildShuffledQueue({Song? firstSong}) {
    final shuffled = List<Song>.from(_normalQueue)..shuffle();
    if (firstSong != null) {
      final pinnedIndex = shuffled.indexWhere((s) => s == firstSong);
      if (pinnedIndex >= 0) {
        final pinnedSong = shuffled.removeAt(pinnedIndex);
        shuffled.insert(0, pinnedSong);
      }
    }
    _shuffledQueue = shuffled;
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
    _logger.fine("Adding ${songs.length} song(s) to queue");
    final existingHashes = _normalQueue.map((s) => s.getHash()).toSet();
    final toAdd =
        songs.where((s) => !existingHashes.contains(s.getHash())).toList();
    if (toAdd.isEmpty) return;

    _normalQueue.addAll(toAdd);
    _shuffledQueue.addAll(toAdd);
    _queuePlaylist = await playlistService.addToPlaylist(_queuePlaylist, toAdd);
    _notifyQueueMutation();
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    var insertedAny = false;

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
      insertedAny = true;
    }

    if (!insertedAny) return;
    await playlistService.updatePlaylist(_queuePlaylist);
    _notifyQueueMutation();
  }

  Future<void> removeFromQueue(Song song) async {
    final activeIdx = _activeQueue.indexWhere((s) => s == song);
    if (activeIdx == -1) return;
    if (_normalQueue.length <= 1) {
      _logger.fine(
        '[AppAudioService] Refusing to remove last queue entry to keep queue non-empty',
      );
      return;
    }

    final wasCurrentSong = song == currentSong;
    _normalQueue.remove(song);
    _shuffledQueue.remove(song);
    await playlistService.deleteFromPlaylist(song, _queuePlaylist);
    _notifyQueueMutation();

    if (wasCurrentSong) {
      _currentIndex = _currentIndex.clamp(0, _activeQueue.length - 1);
      if (!await _loadIndex(_currentIndex)) return;
      await play();
    } else if (activeIdx < _currentIndex) {
      _currentIndex--;
    }
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty) return;

    _ttfaRequestedAt = DateTime.now();
    _ttfaLoadingSeen = false;
    _invalidateLoadRequests();
    final requestVersion = _loadRequestVersion;

    if (!songs.equals(_normalQueue)) {
      _logger.fine("updating queue with new songs");
      _normalQueue.clear();
      _normalQueue.addAll(songs);
      _queuePlaylist.clearSongs();
      _queuePlaylist = await playlistService.addToPlaylist(
        _queuePlaylist,
        _normalQueue,
      );
      if (requestVersion != _loadRequestVersion) return;
      _rebuildShuffledQueue(
        firstSong: _currentAudioSettings.shuffle ? song : null,
      );
      _notifyQueueMutation();
    }

    await setCurrentSongAndPlay(song);
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    if (_ttfaRequestedAt == null) {
      _ttfaRequestedAt = DateTime.now();
      _ttfaLoadingSeen = false;
    }
    currentSong = song;
    _bindSongPeerCountNotifier(song);
    try {
      if (_currentAudioSettings.shuffle) {
        _rebuildShuffledQueue(firstSong: song);
        _currentIndex = 0;
        _notifyQueueMutation();
      } else {
        final idx = _activeQueue.indexWhere((s) => s == song);
        _currentIndex = idx < 0 ? 0 : idx;
      }
      if (!await _loadIndex(_currentIndex)) return;
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
      _rebuildShuffledQueue(firstSong: currentSong);
      final idx = _activeQueue.indexWhere((s) => s == currentSong);
      _currentIndex = idx < 0 ? 0 : idx;
      if (!UniversalPlatform.isWeb) {
        final restore = _loadIndex(
          _currentIndex,
          position: _currentAudioSettings.sliderInSeconds,
        );
        try {
          await restore.timeout(_sessionRestoreTimeout);
        } catch (e) {
          _logger.warning('Could not restore last played song at startup: $e');
          unawaited(
            restore.catchError((Object error) {
              _logger.fine('Deferred session restore failure: $error');
              return false;
            }),
          );
        }
      }
    }
  }

  Future<void> _onSongCompleted() async {
    _logger.fine(
      '[_onSongCompleted] called: queue=${_activeQueue.length}, isSwitching=$_isSwitchingSong, index=$_currentIndex',
    );
    if (_activeQueue.isEmpty || _isSwitchingSong) return;
    _currentIndex = (_currentIndex + 1) % _activeQueue.length;
    if (!await _loadIndex(_currentIndex)) return;
    await play();
  }

  Future<bool> _loadIndex(int idx, {int? position}) async {
    _logger.fine('[AppAudioService] _loadAndPlayIndex($idx) called');
    if (_activeQueue.isEmpty) return false;
    final requestVersion = ++_loadRequestVersion;
    _isSwitchingSong = true;
    _finalizePlayDuration();
    _logger.fine(
      '[AppAudioService] Loading song at index $idx: ${_activeQueue[idx].getName()}',
    );

    try {
      final outgoing = currentSong;
      if (outgoing != null &&
          !outgoing.hasLocalFile &&
          outgoing.getHash().isNotEmpty) {
        createChunkManager(outgoing.getHash()).flushStats();
      }

      final queuedSong = _activeQueue[idx];
      final song = await _fullyFetchQueueSong(queuedSong);
      if (requestVersion != _loadRequestVersion) return false;
      song.localSourceKey ??= queuedSong.localSourceKey;
      final resolvedSource = _sourceForPlayback(song, queuedSong);
      if (UniversalPlatform.isWeb && !resolvedSource.isLocal) {
        if (_onBeforeWebPlayback == null) {
          _useWebServiceWorkerStream = false;
        } else {
          _useWebServiceWorkerStream = await _onBeforeWebPlayback!.call();
          if (requestVersion != _loadRequestVersion) return false;
        }
      }
      final installedSource = await _installSource(
        requestVersion,
        song,
        queuedSong,
        resolvedSource,
        position,
      );
      if (installedSource == null || requestVersion != _loadRequestVersion) {
        return false;
      }
      _activeSourceIntent = queuedSong.getHash();
      _activePlaybackSource = installedSource;
      currentSong = song;
      if (requestVersion != _loadRequestVersion) return false;
      _onSongStarted(song);
      return true;
    } finally {
      if (requestVersion == _loadRequestVersion) _isSwitchingSong = false;
    }
  }

  Future<Song> _fullyFetchQueueSong(Song queuedSong) async {
    try {
      final fetched = await songService.fullyFetchSong(queuedSong);
      if (fetched.getHash() != queuedSong.getHash()) {
        _logger.warning(
          'Ignoring fetched song with mismatched hash: expected ${queuedSong.getHash()}, got ${fetched.getHash()}',
        );
        return queuedSong;
      }
      if (!identical(queuedSong, fetched)) {
        // Enrich display metadata without replacing queue identity or its source.
        queuedSong
          ..name = fetched.name
          ..durationInSeconds = fetched.durationInSeconds
          ..trackNumber = fetched.trackNumber
          ..discNumber = fetched.discNumber
          ..year = fetched.year
          ..fullyLoaded = fetched.fullyLoaded
          ..artist.target = fetched.artist.target
          ..album.target = fetched.album.target;
      }
      return queuedSong;
    } catch (e) {
      _logger.warning(
        'Failed to fully fetch queued song ${queuedSong.getHash()}',
        e,
      );
      return queuedSong;
    }
  }

  PlaybackSourceSelection _sourceForPlayback(Song song, Song queuedSong) {
    final intent = queuedSong.getHash();
    if (_activeSourceIntent == intent &&
        _activePlaybackSource?.kind == PlaybackSourceKind.remote) {
      return _activePlaybackSource!;
    }
    try {
      final selection = songService.resolvePlaybackSource(song);
      if (selection.kind == PlaybackSourceKind.remote ||
          selection.kind == PlaybackSourceKind.local) {
        return selection;
      }
      return PlaybackSourceSelection.remote(
        queuedSong,
        selection.kind == PlaybackSourceKind.ambiguous
            ? 'ambiguous local source; using remote asset'
            : 'local source unavailable; using remote asset',
      );
    } catch (error) {
      _logger.fine('Playback source resolution failed: $error');
      return PlaybackSourceSelection.remote(
        queuedSong,
        'source resolution unavailable; using remote asset',
      );
    }
  }

  Future<PlaybackSourceSelection?> _installSource(
    int requestVersion,
    Song song,
    Song queuedSong,
    PlaybackSourceSelection selection,
    int? position,
  ) {
    final previous = _sourceInstallTail;
    final next = previous.catchError((_) {}).then((_) async {
      if (requestVersion != _loadRequestVersion) return null;
      if (!UniversalPlatform.isDesktop) {
        await audioPlayer.stop();
        if (requestVersion != _loadRequestVersion) return null;
      }
      try {
        await audioPlayer.setAudioSource(
          _buildAudioSource(song, selection),
          initialPosition: Duration(seconds: position ?? 0),
        );
        return selection;
      } catch (error) {
        if (requestVersion != _loadRequestVersion || !selection.isLocal) {
          rethrow;
        }
        _logger.warning(
          'Local playback source failed; falling back to remote: $error',
        );
        final remote = PlaybackSourceSelection.remote(
          queuedSong,
          'local source failed during load',
        );
        _rejectActiveLocalSource();
        if (requestVersion != _loadRequestVersion) return null;
        await audioPlayer.setAudioSource(
          _buildAudioSource(song, remote),
          initialPosition: Duration(seconds: position ?? 0),
        );
        return remote;
      }
    });
    _sourceInstallTail = next.catchError((_) => null);
    return next;
  }

  void _rejectActiveLocalSource() {
    if (_activePlaybackSource?.isLocal != true || _activeSourceIntent == null) {
      return;
    }
    _activePlaybackSource = PlaybackSourceSelection.remote(
      _activeQueue.firstWhere(
        (song) => song.getHash() == _activeSourceIntent,
        orElse: () => currentSong!,
      ),
      'local source rejected after player error',
    );
  }

  void _invalidateLoadRequests() {
    _loadRequestVersion++;
    _isSwitchingSong = false;
    _activeSourceIntent = null;
    _activePlaybackSource = null;
  }

  AudioSource _buildAudioSource(Song song, PlaybackSourceSelection selection) {
    if (selection.kind == PlaybackSourceKind.unavailable ||
        selection.kind == PlaybackSourceKind.ambiguous) {
      throw StateError('No eligible playback source');
    }
    // Offline availability and playback source are separate concepts. A fully
    // cached remote song is offline-playable but still uses the chunk source.
    final bool isServerTrack = !selection.isLocal;
    final remoteHash = selection.remoteAssetHash ?? song.getHash();

    if (isServerTrack) {
      if (UniversalPlatform.isWeb && _useWebServiceWorkerStream) {
        _onWebSongChange?.call(song.getHash(), song.getName());
        return AudioSource.uri(
          Uri.parse('${Uri.base.resolve('p2p-stream/').toString()}$remoteHash'),
          tag: Map<String, dynamic>.from({
            "path": song.path,
            "fileHash": remoteHash,
            "song": song,
          }),
        );
      }

      return P2PChunkedAudioSource(
        fileHash: remoteHash,
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
          "fileHash": remoteHash,
          "song": song,
        }),
      );
    } else {
      if (selection.sourceUri == null || selection.sourceUri!.isEmpty) {
        _logger.warning(
          "Warning: Song ${song.getName()} is marked as local but has no path",
        );
      }
      final localPath = selection.sourceUri!;
      final parsed = Uri.tryParse(localPath);
      final localUri =
          parsed != null && parsed.hasScheme ? parsed : Uri.file(localPath);
      return AudioSource.uri(
        localUri,
        tag: Map<String, dynamic>.from({
          "path": localPath,
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

    final playing = currentSong;
    if (playing != null &&
        !playing.hasLocalFile &&
        playing.getHash().isNotEmpty) {
      createChunkManager(playing.getHash());
    }

    final q = _activeQueue;
    for (int i = 0; i < _nextSongTargets.length; i++) {
      final songIdx = (_currentIndex + i + 1) % q.length;
      if (songIdx == _currentIndex) continue;
      final song = q[songIdx];
      if (song.hasLocalFile || song.getHash().isEmpty) continue;
      unawaited(_prefetchSongFraction(song, _nextSongTargets[i] * progress));
    }

    for (int i = 0; i < _prevSongTargets.length; i++) {
      final songIdx = (_currentIndex - i - 1 + q.length) % q.length;
      if (songIdx == _currentIndex) continue;
      final song = q[songIdx];
      if (song.hasLocalFile || song.getHash().isEmpty) continue;
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

  Future<void> downloadSong(Song song) async {
    final remoteHash = song.potentialRemoteHashes.firstOrNull ?? song.fileHash;
    if (remoteHash.isEmpty || !song.isAvailableToStream) {
      throw StateError('Song is not available to stream');
    }
    final manager = createChunkManager(remoteHash);
    manager.configureSongInfo(
      song.getName(),
      ChunkStatsService.instance.reportSilently,
    );
    await manager.downloadAll();
  }

  Future<void> likeCurrentSong() async {
    currentSongNotifier.value?.likedByUser =
        !currentSongNotifier.value!.likedByUser;
    likedNotifier.value = currentSongNotifier.value!.likedByUser;
    await songService.updateSong(currentSongNotifier.value!);
  }

  void _onSongStarted(Song song) {
    _bindSongPeerCountNotifier(song);
    unawaited(_maybeExtendQueueForAutoPlay());
    song.lastPlayed = DateTime.now();
    song.playCount += 1;
    _playStartTime = DateTime.now();
    songService.updateSong(song);
    _proactivelyCachePrefixes();

    if (song.hasLocalFile) {
      ChunkStatsService.instance.report(
        ChunkStat(
          songFileHash: song.getHash(),
          songName: song.getName(),
          localChunks: 1,
        ),
      );
    }
  }

  Future<void> _maybeExtendQueueForAutoPlay() async {
    _logger.fine(
      '[autoPlay] Checking if queue extension needed: autoPlay=${_currentAudioSettings.autoPlay}, inLastThree=${_activeQueue.length - _currentIndex <= 3}, fetchInProgress=$_autoPlayFetchInProgress',
    );
    if (!_currentAudioSettings.autoPlay || _autoPlayFetchInProgress) {
      return;
    }

    final queueLength = _activeQueue.length;
    if (queueLength == 0) return;

    final lastThreeStart = queueLength - 3;
    final inLastThree =
        _currentIndex >= (lastThreeStart > 0 ? lastThreeStart : 0);

    if (!inLastThree) {
      _autoPlayTailFetchArmed = true;
      return;
    }

    if (!_autoPlayTailFetchArmed) {
      return;
    }

    _autoPlayTailFetchArmed = false;
    _autoPlayFetchInProgress = true;
    try {
      final page = await songService.getRecommendations(
        _currentAudioSettings.autoPlayRecommendationsPage,
        5,
      );
      _currentAudioSettings.autoPlayRecommendationsPage++;
      await settingsService.updateAudioSettings(_currentAudioSettings);
      if (page.content.isEmpty) return;
      await addToQueue(page.content);
      _logger.fine(
        '[autoPlay] Added ${page.content.length} recommended song(s) from page ${page.page}',
      );
    } catch (e) {
      _logger.warning('[autoPlay] Failed to extend queue: $e');
    } finally {
      _autoPlayFetchInProgress = false;
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

  void _notifyQueueMutation() {
    queueMutationNotifier.value++;
  }

  void _bindSongPeerCountNotifier(Song song) {
    if (_boundPeerStateNotifier != null && _boundPeerStateListener != null) {
      _boundPeerStateNotifier!.removeListener(_boundPeerStateListener!);
    }
    _boundPeerStateNotifier = null;
    _boundPeerStateListener = null;

    if (song.hasLocalFile || song.getHash().isEmpty) {
      songPeerCountNotifier.value = 0;
      return;
    }

    final manager = createChunkManager(song.getHash());
    songPeerCountNotifier.value = manager.availablePeerCount;
    _boundPeerStateNotifier = manager.peerStateVersionNotifier;
    _boundPeerStateListener = () {
      final current = currentSong;
      if (current == null ||
          current.hasLocalFile ||
          current.getHash().isEmpty ||
          current.getHash() != song.getHash()) {
        songPeerCountNotifier.value = 0;
        return;
      }
      songPeerCountNotifier.value = manager.availablePeerCount;
    };
    _boundPeerStateNotifier!.addListener(_boundPeerStateListener!);
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> dispose() async {
    _invalidateLoadRequests();
    if (_boundPeerStateNotifier != null && _boundPeerStateListener != null) {
      _boundPeerStateNotifier!.removeListener(_boundPeerStateListener!);
    }
    _positionSaveTimer?.cancel();
    await _processingStateSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _errorSubscription?.cancel();
    await audioPlayer.dispose();
  }
}
