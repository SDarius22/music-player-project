import 'package:audioplayers/audioplayers.dart';
import 'package:music_player_frontend/core/audio_player/abstract_audio_player.dart';
import 'package:music_player_frontend/core/audio_player/player_state.dart'
    as player_state;

class ConcreteAudioPlayer extends AbstractAudioPlayer {
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  Future<void> dispose() async {
    await audioPlayer.dispose();
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    return await audioPlayer.getCurrentPosition();
  }

  @override
  Future<Duration?> getDuration() async {
    return await audioPlayer.getDuration();
  }

  @override
  Future<void> pause() async {
    await audioPlayer.pause();
  }

  @override
  Future<void> play() async {
    await audioPlayer.play(audioPlayer.source ?? AssetSource(''));
  }

  @override
  Future<void> seek(Duration position) async {
    audioPlayer.seek(position);
  }

  @override
  Future<void> setBalance(double balance) async {
    await audioPlayer.setBalance(balance);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await audioPlayer.setPlaybackRate(speed);
  }

  @override
  Future<void> setSource(String source) async {
    await audioPlayer.setSource(DeviceFileSource(source));
  }

  @override
  Future<void> setVolume(double volume) async {
    await audioPlayer.setVolume(volume);
  }

  @override
  Future<void> stop() async {
    await audioPlayer.stop();
  }

  @override
  Stream<player_state.PlayerState> get onPlayerStateChanged =>
      audioPlayer.onPlayerStateChanged.map((state) {
        switch (state) {
          case PlayerState.playing:
            return player_state.PlayerState.playing;
          case PlayerState.paused:
            return player_state.PlayerState.paused;
          case PlayerState.stopped:
            return player_state.PlayerState.stopped;
          case PlayerState.completed:
            return player_state.PlayerState.completed;
          default:
            return player_state.PlayerState.stopped;
        }
      });

  @override
  Stream<Duration> get onPositionChanged => audioPlayer.onPositionChanged;
}
