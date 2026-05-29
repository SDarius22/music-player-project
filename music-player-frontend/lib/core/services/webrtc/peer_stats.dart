final class PeerStats {
  static const double _alpha = 0.2;

  double rttMs = 500.0;
  double throughputBytesPerMs = 0.001;
  int successes = 0;
  int failures = 0;
  double? setupMs;

  double get successRate {
    final total = successes + failures;
    return total == 0 ? 0.5 : successes / total;
  }

  double get score => successRate * throughputBytesPerMs * 1000 / (rttMs + 1);

  void recordRtt(double ms) {
    rttMs = _alpha * ms + (1 - _alpha) * rttMs;
  }

  void recordDelivery(int bytes, double elapsedMs) {
    successes++;
    final tput = bytes / elapsedMs.clamp(1, double.infinity);
    throughputBytesPerMs = _alpha * tput + (1 - _alpha) * throughputBytesPerMs;
  }

  void recordFailure() {
    failures++;
  }
}
