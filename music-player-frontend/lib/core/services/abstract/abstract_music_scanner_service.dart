abstract class AbstractMusicScannerService {
  Future<void> performQuickScan();

  Stream<double> get progressStream;
}
