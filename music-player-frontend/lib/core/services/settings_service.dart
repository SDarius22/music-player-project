import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';

class SettingsService {
  final SettingsRepository _settingsRepository;
  AudioSettings currentAudioSettings = AudioSettings();
  AppSettings currentAppSettings = AppSettings();

  SettingsService(this._settingsRepository) {
    _settingsRepository.getAppSettings() == null
        ? _settingsRepository.saveAppSettings(currentAppSettings)
        : currentAppSettings = _settingsRepository.getAppSettings()!;

    _settingsRepository.getAudioSettings() == null
        ? _settingsRepository.saveAudioSettings(currentAudioSettings)
        : currentAudioSettings = _settingsRepository.getAudioSettings()!;
  }

  void updateAudioSettings() {
    _settingsRepository.saveAudioSettings(currentAudioSettings);
  }

  void resetAudioSettings() {
    currentAudioSettings = AudioSettings();
    _settingsRepository.deleteAllAudioSettings();
    _settingsRepository.saveAudioSettings(currentAudioSettings);
  }

  void updateAppSettings() {
    _settingsRepository.saveAppSettings(currentAppSettings);
  }

  void resetAppSettings() async {
    currentAppSettings = AppSettings();
    _settingsRepository.deleteAllAppSettings();
    _settingsRepository.saveAppSettings(currentAppSettings);
  }
}
