import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/worker_service.dart';

class AudioProvider extends BaseAudioHandler with SeekHandler, ChangeNotifier {
  final AppAudioService _audioService;
  final FileService _fileService;

  ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> repeatNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> shuffleNotifier = ValueNotifier<bool>(false);
  ValueNotifier<int> sliderNotifier = ValueNotifier<int>(0);
  ValueNotifier<int> bufferedPositionNotifier = ValueNotifier<int>(0);
  ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> playbackSpeedNotifier = ValueNotifier<double>(1.0);

  ValueNotifier<Song> get currentSongNotifier =>
      _audioService.currentSongNotifier;

  ValueNotifier<bool> get likedNotifier => _audioService.likedNotifier;

  Song get currentSong => currentSongNotifier.value;

  int get currentIndexInNonShuffled => normalQueue.indexOf(currentSong);

  List<Song> get normalQueue => _audioService.queue;

  AudioSettings get _currentAudioSettings => _audioService.currentAudioSettings;

  AudioProvider(this._audioService, this._fileService) {
    repeatNotifier.value = _currentAudioSettings.repeat;
    shuffleNotifier.value = _currentAudioSettings.shuffle;
    volumeNotifier.value = _currentAudioSettings.volume;

    sliderNotifier.value = currentSong.durationInSeconds;

    _startListeners();
    _setColors();
    _changeMediaItem();
    notifyListeners();
  }

  @override
  void dispose() {
    disposeListeners();
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
      debugPrint("Error skipping to next: $e");
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

  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    await _audioService.setQueueAndPlay(songs, song);
    notifyListeners();
  }

  Future<Duration> getDuration() async {
    if (currentSong.durationInSeconds > 0) {
      return Duration(seconds: currentSong.durationInSeconds);
    }
    return await _audioService.getDuration();
  }

  void addLastToQueue(List<Song> songs) {
    _audioService.addToQueue(songs);
    notifyListeners();
  }

  void addNextToQueue(List<Song> songs) {
    _audioService.addNextToQueue(songs);
    notifyListeners();
  }

  void removeFromQueue(Song song) {
    _audioService.removeFromQueue(song);
    notifyListeners();
  }

  Future<void> setCurrentSongAndPlay(Song song) async {
    await _audioService.setCurrentSongAndPlay(song);
  }

  void likeCurrentSong() {
    _audioService.likeCurrentSong();
  }

  Future<void> _changeMediaItem() async {
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

  Future<void> _setColors() async {
    if (currentSong.coverArt == Constants.logoBytes ||
        currentSong.colors.isNotEmpty) {
      debugPrint("Skipping color extraction for ${currentSong.name}");
      return;
    }

    currentSong.album.target!.colors = await WorkerService.extractColors(
      currentSong.album.target!.coverArt,
    );
  }

  void _startListeners() {
    _audioService.currentSongNotifier.addListener(() {
      _setColors();
      _changeMediaItem();
      notifyListeners();
    });

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
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  void disposeListeners() {
    _audioService.audioPlayer.positionStream.drain();
    _audioService.audioPlayer.bufferedPositionStream.drain();
    _audioService.audioPlayer.playbackEventStream.drain();
  }
}
