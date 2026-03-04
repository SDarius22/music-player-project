import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';

class SettingsService {
  final SettingsRepository _settingsRepository;

  SettingsService(this._settingsRepository);

  AudioSettings getAudioSettings() {
    return _settingsRepository.getAudioSettings();
  }

  AppSettings getAppSettings() {
    return _settingsRepository.getAppSettings();
  }

  void updateAudioSettings(AudioSettings newSettings) {
    _settingsRepository.saveAudioSettings(newSettings);
  }

  void updateAppSettings(AppSettings newSettings) {
    _settingsRepository.saveAppSettings(newSettings);
  }
}
