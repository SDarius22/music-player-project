import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/local_libs/extensions.dart';

class AppAudioService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final SongService songService;
  final SettingsService settingsService;
  final PlaylistService playlistService;

  final Future<ChunkService> Function(int songId) createChunkManager;

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

    final currentIndexNormal = _normalQueue.indexOf(currentSong);
    var insertAt =
        currentIndexNormal >= 0 ? currentIndexNormal + 1 : _normalQueue.length;

    List<AudioSource> sourcesToInsert = [];

    for (final song in songs.reversed) {
      if (_normalQueue.contains(song)) continue;
      _normalQueue.insert(insertAt, song);

      _queuePlaylist.songs.add(song);
      _queuePlaylist.songsIds.insert(insertAt, song.id);

      sourcesToInsert.add(await _buildAudioSource(song));
    }

    playlistService.updatePlaylist(_queuePlaylist);
    await audioPlayer.insertAudioSources(insertAt, sourcesToInsert);
  }

  Future<void> removeFromQueue(Song song) async {
    if (!_normalQueue.contains(song)) return;

    _normalQueue.remove(song);
    playlistService.deleteFromPlaylist(song, _queuePlaylist);

    var audioSources = audioPlayer.audioSources;
    await audioPlayer.removeAudioSourceAt(
      audioSources.indexWhere((source) {
        if (source is IndexedAudioSource) {
          final songMap = source.tag as Map<String, dynamic>?;
          final taggedSong = songMap?["song"] as Song?;
          return taggedSong?.id == song.id;
        }
        return false;
      }),
    );
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    if (songs.isEmpty || songs.equals(_normalQueue)) {
      debugPrint(
        "Queue is the same as current. Just playing the selected song.",
      );
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
      if (currentSource == null) return;

      final songMap = currentSource.tag as Map<String, dynamic>?;
      final song = songMap?["song"] as Song?;

      if (song != null && song.id != currentSong.id) {
        _updateCurrentSong(song);
      }
    });

    audioPlayer.errorStream.listen((error) {
      debugPrint("Audio Player Error: $error");
    });
  }

  int _getPlayIndex(Song song) {
    final playIndex = audioPlayer.audioSources.indexWhere((source) {
      if (source is IndexedAudioSource) {
        final taggedSong = source.tag as Map<String, dynamic>?;
        return (taggedSong!["path"].toString().isNotEmpty &&
                taggedSong["path"] == song.path) ||
            (taggedSong["serverId"] != null &&
                taggedSong["serverId"] == song.serverId);
      }
      return false;
    });
    return playIndex != -1 ? playIndex : 0;
  }

  Future<void> _setAudioSourcesForQueue(Song song) async {
    if (_normalQueue.isEmpty) return;

    final sources = await Future.wait(queue.map((s) => _buildAudioSource(s)));

    await audioPlayer.setAudioSources(sources);

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

  Future<AudioSource> _buildAudioSource(Song song) async {
    bool isServerTrack = !song.isLocal;

    if (isServerTrack) {
      final chunkManager = await createChunkManager(song.serverId);
      return P2PChunkedAudioSource(
        chunkManager: chunkManager,
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
    final currentIndex = _normalQueue.indexOf(currentSong);
    if (currentIndex == -1) return;

    final int lookaheadCount = 2;
    final int endIndex = (currentIndex + 1 + lookaheadCount).clamp(
      0,
      _normalQueue.length,
    );

    final upcomingSongs = _normalQueue.sublist(currentIndex + 1, endIndex);

    for (final song in upcomingSongs) {
      if (song.serverId > 0) {
        try {
          final manager = await createChunkManager(song.serverId);

          final existingChunk = await manager.cacheRepo.readChunk(
            song.serverId,
            0,
          );

          if (existingChunk == null) {
            debugPrint("Proactively Prefix Caching Song ID ${song.serverId}");
            // This triggers the Fast-Path we wrote above, instantly saving it to disk
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
    if (updated.path == currentSong.path) return;

    currentSong = updated;

    currentSongNotifier.value.lastPlayed = DateTime.now();
    currentSongNotifier.value.playCount += 1;

    songService.updateSong(currentSong);
    playlistService.updateMostPlayedPlaylist();
    playlistService.updateRecentlyPlayedPlaylist();

    // _proactivelyCachePrefixes();
  }

  void updateSliderInSeconds(int seconds) {
    _currentAudioSettings.sliderInSeconds = seconds;
    settingsService.updateAudioSettings(_currentAudioSettings);
  }

  Future<void> dispose() async {
    await audioPlayer.dispose();
  }
}
