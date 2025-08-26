import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';

class SettingsService {
  final SettingsRepository _settingsRepository;

  SettingsService(this._settingsRepository) {
    if (_settingsRepository.getAppSettings() == null) {
      _settingsRepository.saveAppSettings(AppSettings());
    }
    if (_settingsRepository.getAudioSettings() == null) {
      _settingsRepository.saveAudioSettings(AudioSettings());
    }
  }

  AudioSettings getAudioSettings() {
    return _settingsRepository.getAudioSettings() ?? AudioSettings();
  }

  void updateAudioSettings(AudioSettings settings) {
    _settingsRepository.saveAudioSettings(settings);
  }

  void resetAudioSettings() {
    _settingsRepository.deleteAllAudioSettings();
    _settingsRepository.saveAudioSettings(AudioSettings());
  }

  AppSettings getAppSettings() {
    return _settingsRepository.getAppSettings() ?? AppSettings();
  }

  void updateAppSettings(AppSettings settings) {
    _settingsRepository.saveAppSettings(settings);
  }

  void resetAppSettings() async {
    _settingsRepository.deleteAllAppSettings();
    _settingsRepository.saveAppSettings(AppSettings());
  }
}
