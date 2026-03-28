import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/core/services/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/playback_rest_service.dart';
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
  final PlaybackRestService? playbackRestService;
  final ChunkService Function(int songId) createChunkManager;

  ValueNotifier<Song> currentSongNotifier = ValueNotifier<Song>(Song());
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);

  bool _initialized = false;
  bool _isSwitchingSong = false;
  int _currentIndex = 0;
  final Completer<void> _initDone = Completer<void>();

  List<Song> _normalQueue = [];
  Playlist _queuePlaylist = Playlist();
  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  List<Song> get queue => _normalQueue;

  int get currentIndex => _currentIndex;

  Song get currentSong => currentSongNotifier.value;

  set currentSong(Song song) {
    currentSongNotifier.value = song;
    likedNotifier.value = song.likedByUser;
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
    currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _normalQueue = _queuePlaylist.songsList;
    _initPlayer();

    this.audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongCompleted();
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
    await _loadAndPlayIndex(_currentIndex);
  }

  Future<void> pause() => audioPlayer.pause();

  Future<void> skipToNext() async {
    if (_normalQueue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _normalQueue.length;
    await _loadAndPlayIndex(_currentIndex);
  }

  Future<void> skipToPrevious() async {
    if (_normalQueue.isEmpty) return;
    _currentIndex =
        _currentIndex > 0 ? _currentIndex - 1 : _normalQueue.length - 1;
    await _loadAndPlayIndex(_currentIndex);
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
    audioPlayer.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
    pushStateToServer();
  }

  Future<void> setShuffle(bool shuffle) async {
    if (shuffle == _currentAudioSettings.shuffle) return;
    _currentAudioSettings.shuffle = shuffle;
    settingsService.updateAudioSettings(_currentAudioSettings);
    pushStateToServer();
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
    final existingIds = _normalQueue.map((s) => s.id).toSet();
    final toAdd = songs.where((s) => !existingIds.contains(s.id)).toList();
    if (toAdd.isEmpty) return;

    _normalQueue.addAll(toAdd);
    playlistService.addToPlaylist(_queuePlaylist, toAdd);
    pushStateToServer();
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    final insertAt = _normalQueue.isEmpty ? 0 : _currentIndex + 1;

    for (final song in songs.reversed) {
      if (_normalQueue.any((s) => s == song)) continue;
      _normalQueue.insert(insertAt, song);
      _queuePlaylist.songs.add(song);
      _queuePlaylist.songsIds.insert(insertAt, song.id);
    }

    playlistService.updatePlaylist(_queuePlaylist);
    pushStateToServer();
  }

  Future<void> removeFromQueue(Song song) async {
    final idx = _normalQueue.indexWhere((s) => s == song);
    if (idx == -1) return;

    _normalQueue.removeAt(idx);
    playlistService.deleteFromPlaylist(song, _queuePlaylist);

    if (idx < _currentIndex) {
      _currentIndex--;
    } else if (idx == _currentIndex && _normalQueue.isNotEmpty) {
      _currentIndex = _currentIndex % _normalQueue.length;
      await _loadAndPlayIndex(_currentIndex);
    }
    pushStateToServer();
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty) return;

    if (!songs.equals(_normalQueue)) {
      debugPrint("updating queue with new songs");
      _normalQueue.clear();
      _normalQueue.addAll(songs);
      _queuePlaylist.songs.clear();
      _queuePlaylist.songsIds.clear();
      playlistService.addToPlaylist(_queuePlaylist, _normalQueue);
    }

    await setCurrentSongAndPlay(song);
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSong = song;
    try {
      final idx = _normalQueue.indexWhere((s) => s == song);
      _currentIndex = idx < 0 ? 0 : idx;
      await _loadAndPlayIndex(_currentIndex);
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
      final idx = _normalQueue.indexWhere((s) => s == currentSong);
      _currentIndex = idx < 0 ? 0 : idx;
      debugPrint(
        '[_initPlayer] sliderInSeconds=${_currentAudioSettings.sliderInSeconds}, durationInSeconds=${currentSong.durationInSeconds}, song="${currentSong.name}"',
      );
      final source = _buildAudioSource(_normalQueue[_currentIndex]);
      await audioPlayer.setAudioSource(
        source,
        initialPosition: Duration(
          seconds: _currentAudioSettings.sliderInSeconds,
        ),
      );
    }

    if (!_initDone.isCompleted) _initDone.complete();
  }

  Future<void> _onSongCompleted() async {
    debugPrint(
      '[_onSongCompleted] called: queue=${_normalQueue.length}, isSwitching=$_isSwitchingSong, index=$_currentIndex',
    );
    if (_normalQueue.isEmpty || _isSwitchingSong) return;
    if (_currentAudioSettings.shuffle) {
      _currentIndex = Random().nextInt(_normalQueue.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _normalQueue.length;
    }
    await _loadAndPlayIndex(_currentIndex);
  }

  Future<void> _loadAndPlayIndex(int idx) async {
    debugPrint('[AppAudioService] _loadAndPlayIndex($idx) called');
    if (_normalQueue.isEmpty) return;
    await _initDone.future;
    _isSwitchingSong = true;
    final song = _normalQueue[idx];
    currentSong = song;
    if (!UniversalPlatform.isDesktop) {
      await audioPlayer.stop();
    }
    await audioPlayer.setAudioSource(_buildAudioSource(song));
    await play();
    _isSwitchingSong = false;
    _onSongStarted(song);
    pushStateToServer();
  }

  AudioSource _buildAudioSource(Song song) {
    final bool isServerTrack = !song.isLocal;
    debugPrint(
      "Building audio source for song ${song.name} (isLocal: ${song.isLocal})",
    );

    if (isServerTrack) {
      if (UniversalPlatform.isWeb) {
        return AudioSource.uri(
          Uri.parse('/music-player/p2p-stream/${song.serverId}'),
          tag: Map<String, dynamic>.from({
            "path": song.path,
            "serverId": song.serverId,
            "song": song,
          }),
        );
      }

      return P2PChunkedAudioSource(
        songId: song.serverId,
        chunkManagerFactory: (id) {
          final manager = createChunkManager(id);
          manager.configureSongInfo(
            song.name,
            ChunkStatsService.instance.report,
          );
          return manager;
        },
        tag: Map<String, dynamic>.from({
          "path": song.path,
          "serverId": song.serverId,
          "song": song,
        }),
      );
    } else {
      return AudioSource.uri(
        Uri.file(song.path),
        tag: Map<String, dynamic>.from({
          "path": song.path,
          "serverId": song.serverId,
          "song": song,
        }),
      );
    }
  }

  void pushStateToServer() {
    if (playbackRestService == null) return;
    final queueIds = _normalQueue
        .where((s) => !s.isLocal && s.serverId > 0)
        .map((s) => s.serverId)
        .toList();
    final currentId =
        (!currentSong.isLocal && currentSong.serverId > 0)
            ? currentSong.serverId
            : null;
    final dto = PlaybackStateDto(
      queueSongIds: queueIds,
      currentSongId: currentId,
      positionMs: audioPlayer.position.inMilliseconds,
      shuffle: _currentAudioSettings.shuffle,
      repeat: _currentAudioSettings.repeat,
    );
    playbackRestService!.savePlaybackState(dto);
  }

  Future<void> restoreFromServerState(PlaybackStateDto dto) async {
    if (dto.queueSongIds.isEmpty) return;

    final resolvedQueue = dto.queueSongIds
        .map((id) => songService.getSongByServerId(id))
        .whereType<Song>()
        .toList();

    if (resolvedQueue.isEmpty) return;

    // Apply shuffle and repeat settings
    _currentAudioSettings.shuffle = dto.shuffle;
    _currentAudioSettings.repeat = dto.repeat;
    settingsService.updateAudioSettings(_currentAudioSettings);
    await audioPlayer.setLoopMode(dto.repeat ? LoopMode.one : LoopMode.off);

    // Replace queue locally
    _normalQueue.clear();
    _normalQueue.addAll(resolvedQueue);
    _queuePlaylist.songs.clear();
    _queuePlaylist.songsIds.clear();
    playlistService.addToPlaylist(_queuePlaylist, _normalQueue);

    // Resolve current song
    Song current = resolvedQueue.first;
    if (dto.currentSongId != null) {
      final matches =
          resolvedQueue.where((s) => s.serverId == dto.currentSongId);
      if (matches.isNotEmpty) current = matches.first;
    }
    final idx = resolvedQueue.indexOf(current);
    _currentIndex = idx < 0 ? 0 : idx;
    currentSong = current;

    // Load audio source at saved position without auto-playing
    await _initDone.future;
    await audioPlayer.setAudioSource(
      _buildAudioSource(current),
      initialPosition: Duration(milliseconds: dto.positionMs),
    );
  }

  Future<void> _proactivelyCachePrefixes() async {
    if (_normalQueue.isEmpty) return;
    const prefetchSongs = 5;
    const prefixChunks = 8;

    for (int i = 1; i <= prefetchSongs; i++) {
      final songIdx = (_currentIndex + i) % _normalQueue.length;
      final song = _normalQueue[songIdx];
      if (song.serverId <= 0) continue;

      for (int chunkIdx = 0; chunkIdx < prefixChunks; chunkIdx++) {
        try {
          final manager = createChunkManager(song.serverId);
          final existing = await manager.cacheRepo.readChunk(
            song.serverId,
            chunkIdx,
          );
          if (existing == null) {
            debugPrint("Prefix caching song ${song.serverId} chunk $chunkIdx");
            await manager.getChunk(chunkIdx);
          }
        } catch (e) {
          debugPrint(
            "Failed to prefix cache song ${song.serverId} chunk $chunkIdx: $e",
          );
          break;
        }
      }
    }
  }

  void likeCurrentSong() {
    currentSongNotifier.value.likedByUser =
        !currentSongNotifier.value.likedByUser;
    likedNotifier.value = currentSongNotifier.value.likedByUser;
    songService.updateSong(currentSongNotifier.value);
    playlistService.updateFavoritesPlaylist();
  }

  void _onSongStarted(Song song) {
    song.lastPlayed = DateTime.now();
    song.playCount += 1;
    songService.updateSong(song);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();
    _proactivelyCachePrefixes();
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
  }
}
