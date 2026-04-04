import 'dart:async';

import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';

class WebMusicScannerService implements AbstractMusicScannerService {
  final StreamController<double> _progress =
      StreamController<double>.broadcast();

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  Future<void> performQuickScan() async {
    _progress.add(1.0);
  }
}
