abstract class AbstractAudioPlayer {
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<Duration> getCurrentPosition();
  Future<Duration?> getDuration();
  Future<void> setVolume(double volume);
  Future<void> setBalance(double balance);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setSource(String source);
  Future<void> dispose();
}