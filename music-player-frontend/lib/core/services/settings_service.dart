import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/settings_repo.dart';

class SettingsService {
  final SettingsRepo settingsRepo;

  SettingsService(this.settingsRepo);

  AudioSettings getAudioSettings() {
    return settingsRepo.getAudioSettings();
  }

  Future<void> updateAudioSettings(AudioSettings settings) async {
     settingsRepo.updateAudioSettings(settings);
  }

  Future<void> resetAudioSettings() async {
     settingsRepo.resetAudioSettings();
  }

  AppSettings getAppSettings() {
    return settingsRepo.getAppSettings();
  }

  Future<void> updateAppSettings(AppSettings settings) async {
     settingsRepo.updateAppSettings(settings);
  }

  Future<void> resetAppSettings() async {
     settingsRepo.resetAppSettings();
  }
}