import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';

class SettingsRepository {
  Box<AppSettings> get _appSettingsBox => ObjectBox.store.box<AppSettings>();

  Box<AudioSettings> get _audioSettingsBox =>
      ObjectBox.store.box<AudioSettings>();

  AudioSettings saveAudioSettings(AudioSettings settings) {
    settings.id = _audioSettingsBox.put(settings);
    return settings;
  }

  AudioSettings? getAudioSettings() {
    return _audioSettingsBox.query().build().findFirst();
  }

  void deleteAudioSettings(AudioSettings settings) {
    _audioSettingsBox.remove(settings.id);
  }

  void deleteAllAudioSettings() {
    _audioSettingsBox.removeAll();
  }

  AppSettings saveAppSettings(AppSettings settings) {
    settings.id = _appSettingsBox.put(settings);
    return settings;
  }

  AppSettings? getAppSettings() {
    return _appSettingsBox.query().build().findFirst();
  }

  void deleteAppSettings(AppSettings settings) {
    _appSettingsBox.remove(settings.id);
  }

  void deleteAllAppSettings() {
    _appSettingsBox.removeAll();
  }
}
