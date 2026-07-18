enum MusicScanPhase {
  idle,
  discovering,
  scanning,
  enriching,
  completed,
  cancelled,
  failed,
}

class MusicScanProgress {
  final MusicScanPhase phase;
  final int processed;
  final int total;

  const MusicScanProgress(this.phase, {this.processed = 0, this.total = 0});

  double? get fraction => total > 0 ? processed / total : null;

  bool get isRunning =>
      phase == MusicScanPhase.discovering ||
      phase == MusicScanPhase.scanning ||
      phase == MusicScanPhase.enriching;

  @override
  String toString() =>
      'MusicScanProgress(phase: $phase, processed: $processed, total: $total)';
}

abstract class AbstractMusicScannerService {
  Future<void> performQuickScan();

  Future<void> cancelScan();

  Stream<MusicScanProgress> get progressStream;
}
