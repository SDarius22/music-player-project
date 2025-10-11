abstract class AbstractMusicScannerService {
  Future<void> performQuickScan();

  Stream<double> enrichMetadata();
}
