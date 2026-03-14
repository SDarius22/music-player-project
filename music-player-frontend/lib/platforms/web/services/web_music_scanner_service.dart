import 'dart:async';

import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';

/// Web doesn't have access to device-local songs, so scanning is disabled.
class WebMusicScannerService implements AbstractMusicScannerService {
  final StreamController<double> _progress =
      StreamController<double>.broadcast();

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  Future<void> performQuickScan() async {
    // Immediately report "done".
    _progress.add(1.0);
  }
}
