import 'package:music_player_frontend/platforms/macos/services/macos_music_scanner_service.dart';

class IosMusicScannerService extends MacosMusicScannerService {
  IosMusicScannerService(
    super.localTrackService,
    super.fileService,
    super.settingsService,
  );
}
