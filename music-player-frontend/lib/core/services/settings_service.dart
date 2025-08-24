import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';

class SettingsService {
  final SettingsRepo settingsRepo;

  SettingsService(this.settingsRepo);

  AudioSettings? getAudioSettings() {
    AudioSettings? settings = settingsRepo.getAudioSettings();
    if (settings == null) {
      settingsRepo.initAudioSettings();
      settings = settingsRepo.getAudioSettings();
    }
    return settings;
  }

  Future<void> updateAudioSettings(AudioSettings settings) async {
     settingsRepo.updateAudioSettings(settings);
  }

  Future<void> resetAudioSettings() async {
     settingsRepo.resetAudioSettings();
  }

  AppSettings? getAppSettings() {
    AppSettings? settings =  settingsRepo.getAppSettings();
    if (settings == null) {
       settingsRepo.initAppSettings();
      settings =  settingsRepo.getAppSettings();
    }
    return settings;
  }

  Future<void> updateAppSettings(AppSettings settings) async {
     settingsRepo.updateAppSettings(settings);
  }

  Future<void> resetAppSettings() async {
     settingsRepo.resetAppSettings();
  }
}