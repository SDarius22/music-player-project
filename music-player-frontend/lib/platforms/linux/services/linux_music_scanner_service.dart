import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/desktop_music_scanner_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

class LinuxMusicScannerService extends DesktopMusicScannerService {
  LinuxMusicScannerService(
    LocalTrackService localTrackService,
    AbstractFileService fileService,
    SettingsService settingsService,
  ) : super(
        localTrackService,
        fileService,
        settingsService,
        'LinuxMusicScannerService',
      );
}
