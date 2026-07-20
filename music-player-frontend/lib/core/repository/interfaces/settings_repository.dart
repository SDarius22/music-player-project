import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';

abstract class SettingsRepository {
  AudioSettings getAudioSettings();

  AudioSettings saveAudioSettings(AudioSettings settings);

  AppSettings getAppSettings();

  AppSettings saveAppSettings(AppSettings settings);

  void clearAll();
}
