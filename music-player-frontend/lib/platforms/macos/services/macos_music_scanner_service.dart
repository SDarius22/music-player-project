import 'package:music_player_frontend/platforms/desktop/services/desktop_music_scanner_service.dart';

class MacosMusicScannerService extends DesktopMusicScannerService {
  MacosMusicScannerService(
    super.songService,
    super.artistService,
    super.albumService,
    super.fileService,
    super.settingsService,
  );
}
