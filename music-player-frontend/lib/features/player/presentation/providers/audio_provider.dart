import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';

class AudioProvider extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  static final _logger = Logger('AudioProvider');

  final AppAudioService _audioService;
  final AbstractFileService _fileService;

  ValueNotifier<ProcessingState> processingState =
      ValueNotifier<ProcessingState>(ProcessingState.idle);
  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> autoPlayNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> bufferedPositionNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);
  ValueNotifier<Duration> totalDurationNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );

  ValueNotifier<Song?> get currentSongNotifier =>
      _audioService.currentSongNotifier;

  ValueNotifier<bool> get likedNotifier => _audioService.likedNotifier;

  ValueNotifier<int> get songPeerCountNotifier =>
      _audioService.songPeerCountNotifier;

  Song? get currentSong => currentSongNotifier.value;

  int get currentIndexInNonShuffled {
    final current = currentSong;
    if (current == null) return -1;
    return _audioService.normalQueue.indexWhere(
      (s) => s.fileHash == current.fileHash,
    );
  }

  int get currentIndexInPlaybackQueue => playbackQueue.indexOf(currentSong!);

  List<Song> get playbackQueue => _audioService.queue;

  List<Song> get normalQueue => _audioService.normalQueue;

  AudioSettings get _currentAudioSettings => _audioService.currentAudioSettings;

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferedPositionSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  VoidCallback? _playerVersionListener;
  VoidCallback? _queueMutationListener;
  final Set<String> _colorExtractionInProgress = <String>{};
  int _mediaItemGeneration = 0;

  AudioProvider(this._audioService, this._fileService) {
    repeatNotifier.value = _currentAudioSettings.repeat;
    shuffleNotifier.value = _currentAudioSettings.shuffle;
    autoPlayNotifier.value = _currentAudioSettings.autoPlay;
    volumeNotifier.value = _currentAudioSettings.volume;

    sliderNotifier.value = currentSong?.durationInSeconds ?? 0;
    totalDurationNotifier.value = Duration(
      seconds: currentSong?.durationInSeconds ?? 0,
    );

    _startListeners();
    _playerVersionListener = () {
      _logger.fine(
        'AudioPlayer instance replaced (v=${_audioService.playerInstanceVersion.value}); rebinding stream listeners',
      );
      _bindPlayerStreams();
    };
    _audioService.playerInstanceVersion.addListener(_playerVersionListener!);
    _queueMutationListener = () {
      notifyListeners();
    };
    _audioService.queueMutationNotifier.addListener(_queueMutationListener!);

    unawaited(_setColors());
    unawaited(_changeMediaItem());
    notifyListeners();
  }

  @override
  void dispose() {
    disposeListeners();
    if (_playerVersionListener != null) {
      _audioService.playerInstanceVersion.removeListener(
        _playerVersionListener!,
      );
    }
    if (_queueMutationListener != null) {
      _audioService.queueMutationNotifier.removeListener(
        _queueMutationListener!,
      );
    }
    _audioService.audioPlayer.dispose();
    super.dispose();
  }

  @override
  Future<void> play() async {
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        controls: [MediaControl.pause],
      ),
    );
    await _audioService.play();
  }

  @override
  Future<void> pause() async {
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        controls: [MediaControl.play],
      ),
    );
    await _audioService.pause();
  }

  @override
  Future<void> skipToNext() async {
    try {
      await _audioService.skipToNext();
    } catch (e) {
      _logger.warning('Error skipping to next', e);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (sliderNotifier.value > 3000) {
      await seek(Duration.zero);
      return;
    }

    try {
      await _audioService.skipToPrevious();
    } catch (e) {
      _logger.warning('Error skipping to previous', e);
    }
  }

  @override
  Future<void> stop() async {
    await _audioService.stop();
    notifyListeners();
  }

  Future<void> downloadSong(Song song) => _audioService.downloadSong(song);

  @override
  Future<void> seek(Duration position) async {
    sliderNotifier.value = position.inMilliseconds;
    await _audioService.seek(position);
  }

  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    _audioService.setPlaybackSpeed(speed);
  }

  void setVolume(double volume) {
    volumeNotifier.value = volume;
    _audioService.setVolume(volume);
  }

  void setRepeat(bool repeat) {
    repeatNotifier.value = repeat;
    _audioService.setRepeat(repeat);
  }

  void setShuffle(bool shuffle) {
    shuffleNotifier.value = shuffle;
    unawaited(_audioService.setShuffle(shuffle));
  }

  Future<void> setShuffleAndWait(bool shuffle) async {
    shuffleNotifier.value = shuffle;
    await _audioService.setShuffle(shuffle);
  }

  void setAutoPlay(bool autoPlay) {
    autoPlayNotifier.value = autoPlay;
    _audioService.setAutoPlay(autoPlay);
  }

  int getCurrentSongPeerCount() {
    return _audioService.getCurrentSongPeerCount();
  }

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    await _audioService.setQueueAndPlay(songs, song);
    notifyListeners();
  }

  Future<Duration> getDuration() async {
    var currentSongDuration = currentSong?.durationInSeconds ?? 0;
    if (currentSongDuration > 0) {
      return Duration(seconds: currentSongDuration);
    }
    return await _audioService.getDuration();
  }

  Future<void> addLastToQueue(List<Song> songs) async {
    await _audioService.addToQueue(songs);
    notifyListeners();
  }

  Future<void> addNextToQueue(List<Song> songs) async {
    await _audioService.addNextToQueue(songs);
    notifyListeners();
  }

  Future<void> removeFromQueue(Song song) async {
    await _audioService.removeFromQueue(song);
    notifyListeners();
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    await _audioService.setCurrentSongAndPlay(song);
  }

  Future<void> likeCurrentSong() async {
    await _audioService.likeCurrentSong();
  }

  Future<void> _changeMediaItem() async {
    final song = currentSong;
    if (song == null) return;
    final generation = ++_mediaItemGeneration;
    final identity = song.getHash();
    final item = MediaItem(
      id: identity,
      album: song.album.target?.getName() ?? 'Unknown Album',
      title: song.getName(),
      artist: song.artist.target?.getName() ?? 'Unknown Artist',
      duration: Duration(seconds: song.durationInSeconds),
    );

    // Metadata must not depend on optional artwork. Publishing this first also
    // makes the Android notification update immediately on a track change.
    mediaItem.add(item);
    try {
      final tempFile = await _fileService.createWorkaroundFile(song);
      if (tempFile.path.isEmpty || !await tempFile.exists()) return;
      if (generation != _mediaItemGeneration ||
          currentSong?.getHash() != identity) {
        return;
      }
      mediaItem.add(item.copyWith(artUri: tempFile.uri));
    } catch (e) {
      _logger.fine('Media artwork is unavailable for ${song.getName()}: $e');
    }
  }

  Future<void> updateColorsFromCover(BaseEntity entity, Uint8List bytes) async {
    if (bytes.isEmpty) return;

    final song = currentSong;
    if (song == null || !_entityBelongsToCurrentSong(entity, song)) return;

    await _extractColorsForSong(song, bytes);
  }

  bool _entityBelongsToCurrentSong(BaseEntity entity, Song song) {
    if (entity is Song) {
      return entity == song ||
          (entity.potentialIdentityKey?.isNotEmpty == true &&
              entity.potentialIdentityKey == song.potentialIdentityKey);
    }
    if (entity is Album) {
      final album = song.album.target;
      if (album == null) return false;
      return _sameEntitySource(album, entity) ||
          (_normalized(album.name) == _normalized(entity.name) &&
              _normalized(album.artist.target?.name) ==
                  _normalized(entity.artist.target?.name));
    }
    if (entity is Artist) {
      final artist = song.artist.target;
      return artist != null &&
          (_sameEntitySource(artist, entity) ||
              _normalized(artist.name) == _normalized(entity.name));
    }
    return false;
  }

  bool _sameEntitySource(BaseEntity first, BaseEntity second) {
    if (first.getHash() == second.getHash()) return true;
    final firstRemote = switch (first) {
      Album album => album.remoteSourceHashes,
      Artist artist => artist.remoteSourceHashes,
      _ => const <String>[],
    };
    final secondRemote = switch (second) {
      Album album => album.remoteSourceHashes,
      Artist artist => artist.remoteSourceHashes,
      _ => const <String>[],
    };
    return firstRemote.contains(second.getHash()) ||
        secondRemote.contains(first.getHash()) ||
        firstRemote.any(secondRemote.contains);
  }

  String _normalized(String? value) => value?.trim().toLowerCase() ?? '';

  Future<void> _setColors() async {
    final song = currentSong;
    if (song == null || song.getColors().length == 4) {
      _logger.fine('Skipping color extraction');
      return;
    }

    var coverArt = song.getCoverArt();
    if ((coverArt == null || coverArt.isEmpty) && song.hasLocalFile) {
      try {
        coverArt = await _fileService.getImage(
          song.localSourceKey ?? song.path,
        );
      } catch (e) {
        _logger.fine('Local cover unavailable for ${song.getName()}: $e');
      }
    }
    if (coverArt == null || coverArt.isEmpty) return;
    await _extractColorsForSong(song, coverArt);
  }

  Future<void> _extractColorsForSong(Song song, Uint8List coverArt) async {
    final album = song.album.target;
    if (album == null || coverArt.isEmpty || album.colors.length == 4) return;

    final key = song.getHash();
    if (!_colorExtractionInProgress.add(key)) return;

    try {
      final colors = await WorkerService.getColorIsolate(coverArt);
      if (colors.length != 4) {
        _logger.warning(
          'Color extraction for ${song.getName()} returned ${colors.length} colors',
        );
        return;
      }

      final current = currentSong;
      if (current == null || current.getHash() != key) return;

      final currentAlbum = current.album.target;
      if (currentAlbum == null) return;

      currentAlbum.colors = colors;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error extracting colors for ${song.getName()}', e);
    } finally {
      _colorExtractionInProgress.remove(key);
    }
  }

  void _startListeners() {
    _audioService.currentSongNotifier.addListener(() {
      if (currentSong == null) {
        playingNotifier.value = false;
        processingState.value = ProcessingState.idle;
        repeatNotifier.value = false;
        shuffleNotifier.value = false;
        autoPlayNotifier.value = false;
        sliderNotifier.value = 0;
        bufferedPositionNotifier.value = 0;
        totalDurationNotifier.value = Duration.zero;
        volumeNotifier.value = 1.0;
        playbackSpeedNotifier.value = 1.0;
        mediaItem.add(null);
        queue.add(const []);
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.idle,
            controls: const [MediaControl.play],
          ),
        );
        notifyListeners();
        return;
      }
      var currentSongDuration = currentSong?.durationInSeconds ?? 0;
      shuffleNotifier.value = _audioService.currentAudioSettings.shuffle;
      repeatNotifier.value = _audioService.currentAudioSettings.repeat;
      autoPlayNotifier.value = _audioService.currentAudioSettings.autoPlay;
      totalDurationNotifier.value = Duration(seconds: currentSongDuration);
      unawaited(_setColors());
      unawaited(_changeMediaItem());
      notifyListeners();
    });

    _bindPlayerStreams();
  }

  void _bindPlayerStreams() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _playbackEventSub?.cancel();

    final player = _audioService.audioPlayer;

    _durationSub = player.durationStream.listen((duration) {
      if (duration == null || duration.inSeconds <= 0) return;
      if (currentSong == null) return;
      var currentSongDuration = currentSong?.durationInSeconds ?? 0;

      if (currentSongDuration <= 0) {
        currentSong!.durationInSeconds = duration.inSeconds;
        _audioService.songService.updateSong(currentSong!);
      }
      totalDurationNotifier.value = duration;
    });

    _positionSub = player.positionStream.listen((Duration event) {
      sliderNotifier.value = event.inMilliseconds;
      _audioService.updateSliderInSeconds(event.inSeconds);
    });

    _bufferedPositionSub = player.bufferedPositionStream.listen((
      Duration event,
    ) {
      bufferedPositionNotifier.value = event.inSeconds;
    });

    _playbackEventSub = player.playbackEventStream.listen((event) {
      var playing = _audioService.audioPlayer.playing;
      playingNotifier.value = playing;
      processingState.value = _audioService.audioPlayer.processingState;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,

            MediaControl.skipToNext,
          ],
          systemActions: {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState:
              const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[_audioService.audioPlayer.processingState]!,
          playing: playing,
          updatePosition: _audioService.audioPlayer.position,
          bufferedPosition: _audioService.audioPlayer.bufferedPosition,
          speed: _currentAudioSettings.speed,
          queueIndex: _audioService.currentIndex,
        ),
      );
    });
  }

  void disposeListeners() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _bufferedPositionSub?.cancel();
    _playbackEventSub?.cancel();
  }
}
