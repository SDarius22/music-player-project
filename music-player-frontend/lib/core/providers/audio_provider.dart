import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';

class AudioProvider extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  final AppAudioService _audioService;
  final FileService _fileService;

  ValueNotifier<bool> likedNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> bufferedPositionNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);
  ValueNotifier<Song> currentSongNotifier = ValueNotifier<Song>(Song());
  List<Song> normalQueue = [];
  List<Song> shuffledQueue = [];

  AudioProvider(this._audioService, this._fileService) {
    normalQueue = List<Song>.from(_audioService.queue);
    shuffledQueue = List<Song>.from(normalQueue)..shuffle();

    currentSongNotifier.value = _audioService.getCurrentSong();
    likedNotifier.value = currentSongNotifier.value.likedByUser;

    repeatNotifier.value = _currentAudioSettings.repeat;
    shuffleNotifier.value = _currentAudioSettings.shuffle;
    volumeNotifier.value = _currentAudioSettings.volume;

    sliderNotifier.value = currentSong.durationInSeconds;

    _startListeners();

    changeMediaItem();
    notifyListeners();
  }

  Song get currentSong => currentSongNotifier.value;

  List<Song> get _currentQueue =>
      _audioService.shuffle ? shuffledQueue : normalQueue;

  int get currentIndexInNonShuffled => normalQueue.indexOf(currentSong);

  int get _currentIndex => _currentQueue.indexOf(currentSong);

  Song get _nextSong =>
      _currentQueue.isNotEmpty
          ? _currentQueue[(_currentIndex + 1) % _currentQueue.length]
          : Song();

  Song get _previousSong =>
      _currentQueue.isNotEmpty
          ? _currentQueue[(_currentIndex - 1 + _currentQueue.length) %
              _currentQueue.length]
          : Song();

  AudioSettings get _currentAudioSettings =>
      _audioService.settingsService.currentAudioSettings;

  @override
  Future<void> play() async {
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        controls: [MediaControl.pause],
      ),
    );
    await _audioService.play(currentSong);
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
    debugPrint("Skipping to next song: ${_nextSong.name}");
    currentSongNotifier.value = _nextSong;
    likedNotifier.value = _nextSong.likedByUser;
    changeMediaItem();
    notifyListeners();
    try {
      await _audioService.skipToNext(currentSong);
    } catch (e) {
      debugPrint("Error skipping to next: $e");
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (sliderNotifier.value > 3000) {
      await seek(Duration.zero);
      return;
    }
    currentSongNotifier.value = _previousSong;
    likedNotifier.value = _previousSong.likedByUser;
    changeMediaItem();
    notifyListeners();
    try {
      await _audioService.skipToPrevious(currentSong);
    } catch (e) {
      debugPrint("Error skipping to previous: $e");
    }
  }

  @override
  Future<void> stop() async {
    await _audioService.stop();
    notifyListeners();
  }

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
    _audioService.setShuffle(shuffle);
  }

  Future<void> setQueue(List<Song> songs) async {
    normalQueue = List<Song>.from(songs);
    shuffledQueue = List<Song>.from(songs)..shuffle();
    _audioService.setQueue(songs);
    notifyListeners();
  }

  Future<Duration> getDuration() async {
    if (currentSong.durationInSeconds > 0) {
      return Duration(seconds: currentSong.durationInSeconds);
    }
    return await _audioService.getDuration();
  }

  void addLastToQueue(List<Song> songs) {
    for (var song in songs) {
      if (!normalQueue.contains(song)) {
        normalQueue.add(song);
        shuffledQueue.insert(Random().nextInt(shuffledQueue.length + 1), song);
      }
    }
    _audioService.addToQueue(songs);
    notifyListeners();
  }

  void addNextToQueue(List<Song> songs) {
    for (Song song in songs.reversed) {
      if (!normalQueue.contains(song)) {
        int currentIndex = currentIndexInNonShuffled;
        int nextIndex = (currentIndex + 1) % normalQueue.length;
        if (nextIndex == 0) {
          normalQueue.add(song);
          shuffledQueue.add(song);
        } else {
          normalQueue.insert(nextIndex, song);
          shuffledQueue.insert(nextIndex, song);
        }
        _audioService.addNextToQueue([song]);
      }
    }
    _audioService.addNextToQueue(songs);
    notifyListeners();
  }

  void removeFromQueue(Song song) {
    _audioService.removeFromQueue(song);
    notifyListeners();
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    currentSongNotifier.value = song;
    likedNotifier.value = song.likedByUser;
    await _audioService.setCurrentSongAndPlay(song);
    changeMediaItem();
    notifyListeners();
  }

  void likeCurrentSong() {
    likedNotifier.value = !likedNotifier.value;
    _audioService.likeCurrentSong();
  }

  Future<void> changeMediaItem() async {
    File tempFile = await _fileService.createWorkaroundFile(currentSong);
    MediaItem item = MediaItem(
      id: currentSong.id.toString(),
      album: currentSong.album.target?.name ?? 'Unknown Album',
      title: currentSong.name,
      artist: currentSong.artist.target?.name ?? 'Unknown Artist',
      duration: Duration(seconds: currentSong.durationInSeconds),
      artUri: tempFile.uri,
    );
    mediaItem.add(item);
  }

  void _startListeners() {
    _audioService.audioPlayer.positionStream.listen((Duration event) {
      sliderNotifier.value = event.inMilliseconds;
      _audioService.updateSliderInSeconds(event.inSeconds);
    });

    _audioService.audioPlayer.bufferedPositionStream.listen((Duration event) {
      bufferedPositionNotifier.value = event.inSeconds;
    });

    _audioService.audioPlayer.playbackEventStream.listen((event) {
      var playing = _audioService.audioPlayer.playing;
      playingNotifier.value = playing;

      if (event.processingState == ProcessingState.completed) {
        if (_currentAudioSettings.repeat) {
          pause();
          seek(Duration.zero);
          play();
        } else if (_currentAudioSettings.shuffle) {
          skipToNext();
        }
      }

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
          speed: _audioService.settingsService.currentAudioSettings.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }
}
