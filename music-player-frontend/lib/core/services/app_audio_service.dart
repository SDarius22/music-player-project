import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/local_libs/extensions.dart';
import 'package:universal_platform/universal_platform.dart';

class AppAudioService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;
  final AuthService authService;
  final ChunkService Function(int songId) createChunkManager;

  ValueNotifier<Song> currentSongNotifier = ValueNotifier<Song>(Song());
  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);

  bool _initialized = false;

  // Guard against the sequenceStateStream listener re-entering during moveAudioSource.
  bool _rotating = false;
  List<Song> _normalQueue = [];
  Playlist _queuePlaylist = Playlist();
  AudioSettings _currentAudioSettings = AudioSettings();

  AudioSettings get currentAudioSettings => _currentAudioSettings;

  // _normalQueue[0] is always the currently playing song.
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
    this.authService,
    this.createChunkManager,
  ) {
    _currentAudioSettings = settingsService.getAudioSettings();
    currentSong = playlistService.getMostRecentPlayedSong() ?? Song();
    _queuePlaylist = playlistService.getQueuePlaylist();
    _normalQueue = _queuePlaylist.songsList;
    _initPlayer();
  }

  Future<void> play() => audioPlayer.play();

  Future<void> pause() => audioPlayer.pause();

  // Let just_audio advance to index 1; the sequenceStateStream listener
  // will rotate the played song (index 0) to the end.
  Future<void> skipToNext() async {
    await audioPlayer.seekToNext();
    await audioPlayer.play();
  }

  // Move the last song to the front, then seek to index 0.
  Future<void> skipToPrevious() async {
    if (_normalQueue.length <= 1) {
      await audioPlayer.seek(Duration.zero, index: 0);
      await audioPlayer.play();
      return;
    }
    _rotating = true;
    _normalQueue.insert(0, _normalQueue.removeLast());
    // moveAudioSource shifts indices: player was at 0, now at 1 after insert.
    await audioPlayer.moveAudioSource(_normalQueue.length - 1, 0);
    _rotating = false;
    currentSong = _normalQueue[0];
    await audioPlayer.seek(Duration.zero, index: 0);
    await audioPlayer.play();
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
    final existingIds = _normalQueue.map((s) => s.id).toSet();
    final toAdd = songs.where((s) => !existingIds.contains(s.id)).toList();
    if (toAdd.isEmpty) return;

    _normalQueue.addAll(toAdd);
    playlistService.addToPlaylist(_queuePlaylist, toAdd);

    final sources = await Future.wait(toAdd.map((s) => _buildAudioSource(s)));
    await audioPlayer.addAudioSources(sources);
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;

    // Current song is always at index 0; insert right after it.
    final insertAt = _normalQueue.isEmpty ? 0 : 1;
    List<AudioSource> sourcesToInsert = [];

    for (final song in songs.reversed) {
      if (_normalQueue.any((s) => s.id == song.id)) continue;
      _normalQueue.insert(insertAt, song);
      _queuePlaylist.songs.add(song);
      _queuePlaylist.songsIds.insert(insertAt, song.id);
      sourcesToInsert.add(await _buildAudioSource(song));
    }

    playlistService.updatePlaylist(_queuePlaylist);
    await audioPlayer.insertAudioSources(insertAt, sourcesToInsert);
  }

  Future<void> removeFromQueue(Song song) async {
    final idx = _normalQueue.indexWhere((s) => s.id == song.id);
    if (idx == -1) return;

    _normalQueue.removeAt(idx);
    playlistService.deleteFromPlaylist(song, _queuePlaylist);
    await audioPlayer.removeAudioSourceAt(idx);
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty) return;

    if (songs.equals(_normalQueue)) {
      debugPrint(
        "Queue is the same as current. Just playing the selected song.",
      );
      await setCurrentSongAndPlay(song);
      return;
    }

    _normalQueue = List.from(songs);
    _queuePlaylist.songs.clear();
    _queuePlaylist.songsIds.clear();
    playlistService.addToPlaylist(_queuePlaylist, _normalQueue);
    await setCurrentSongAndPlay(song);
  }

  // Rotate _normalQueue so song is at index 0, rebuild audio sources, play.
  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSong = song;
    try {
      final idx = _normalQueue.indexWhere((s) => s.id == song.id);
      if (idx > 0) {
        _normalQueue = [
          ..._normalQueue.sublist(idx),
          ..._normalQueue.sublist(0, idx),
        ];
      }
      await _rebuildSources();
      await audioPlayer.play();
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
      _currentAudioSettings.repeat ? LoopMode.one : LoopMode.all,
    );

    await _setAudioSourcesForQueue(currentSong);

    audioPlayer.sequenceStateStream.listen((state) async {
      if (_rotating) return;

      final currentSource = state.currentSource;
      if (currentSource == null) return;

      final songMap = currentSource.tag as Map<String, dynamic>?;
      final song = songMap?["song"] as Song?;

      if (song != null && song.id != currentSong.id) {
        _rotating = true;
        _normalQueue.add(_normalQueue.removeAt(0));
        await audioPlayer.moveAudioSource(0, _normalQueue.length - 1);
        _rotating = false;
        _updateCurrentSong(song);
      }
    });

    audioPlayer.errorStream.listen((error) {
      debugPrint("Audio Player Error: $error");
    });
  }

  Future<void> _rebuildSources() async {
    if (_normalQueue.isEmpty) return;
    final sources = await Future.wait(
      _normalQueue.map((s) => _buildAudioSource(s)),
    );
    await audioPlayer.setAudioSources(sources);
    if (_currentAudioSettings.shuffle) {
      audioPlayer.setShuffleModeEnabled(true);
    }
    await audioPlayer.seek(Duration.zero, index: 0);
  }

  Future<void> _setAudioSourcesForQueue(Song song) async {
    if (_normalQueue.isEmpty) return;

    final idx = _normalQueue.indexWhere((s) => s.id == song.id);
    if (idx > 0) {
      _normalQueue = [
        ..._normalQueue.sublist(idx),
        ..._normalQueue.sublist(0, idx),
      ];
    }

    final sources = await Future.wait(
      _normalQueue.map((s) => _buildAudioSource(s)),
    );
    await audioPlayer.setAudioSources(sources);

    if (_currentAudioSettings.shuffle) {
      audioPlayer.setShuffleModeEnabled(true);
    }

    await audioPlayer.seek(
      Duration(seconds: _currentAudioSettings.sliderInSeconds),
      index: 0,
    );
  }

  Future<AudioSource> _buildAudioSource(Song song) async {
    bool isServerTrack = !song.isLocal;

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
        chunkManagerFactory: createChunkManager,
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

  Future<void> _proactivelyCachePrefixes() async {
    for (final song in _normalQueue.skip(1).take(2)) {
      if (song.serverId > 0) {
        try {
          final manager = createChunkManager(song.serverId);
          final existingChunk = await manager.cacheRepo.readChunk(
            song.serverId,
            0,
          );
          if (existingChunk == null) {
            debugPrint("Proactively Prefix Caching Song ID ${song.serverId}");
            await manager.getChunk(0);
          }
        } catch (e) {
          debugPrint(
            "Failed to prefix cache upcoming song ${song.serverId}: $e",
          );
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

  void _updateCurrentSong(Song updated) {
    if (updated == currentSong) return;

    currentSong = updated;

    currentSongNotifier.value.lastPlayed = DateTime.now();
    currentSongNotifier.value.playCount += 1;

    songService.updateSong(currentSong);
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
