import 'package:audio_service/audio_service.dart';
import 'package:music_player_frontend/core/services/abstract/abstract_audio_service.dart';

class SystemAudioHandler extends BaseAudioHandler {
  final AppAudioService audioService;

  SystemAudioHandler(this.audioService) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      systemActions: {MediaAction.seek},
      playing: false,
    ));
  }

  @override
  Future<void> play() async {
    await audioService.play();
  }

  @override
  Future<void> pause() async {
    await audioService.pause();
  }

  @override
  Future<void> skipToNext() async {
    await audioService.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await audioService.skipToPrevious();
  }

  @override
  Future<void> stop() async {
    await audioService.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await audioService.seek(position);
  }


}