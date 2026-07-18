import 'dart:async';

import 'package:music_player_frontend/core/services/abstract/abstract_music_scanner_service.dart';

class WebMusicScannerService implements AbstractMusicScannerService {
  final StreamController<MusicScanProgress> _progress =
      StreamController<MusicScanProgress>.broadcast();

  @override
  Stream<MusicScanProgress> get progressStream => _progress.stream;

  @override
  Future<void> performQuickScan() async {
    _progress.add(const MusicScanProgress(MusicScanPhase.completed));
  }

  @override
  Future<void> cancelScan() async {}
}
