import 'package:music_player_frontend/platforms/desktop/services/desktop_music_scanner_service.dart';

class LinuxMusicScannerService extends DesktopMusicScannerService {
  LinuxMusicScannerService(
    super.songService,
    super.artistService,
    super.albumService,
    super.fileService,
    super.settingsService,
  );
}
