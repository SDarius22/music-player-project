import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';

class SettingsService {
  Box<AppSettings> get _appSettingsBox => ObjectBox.store.box<AppSettings>();
  Box<AudioSettings> get _audioSettingsBox => ObjectBox.store.box<AudioSettings>();

  SettingsService() {
    if (_appSettingsBox.count() == 0) {
      _appSettingsBox.put(AppSettings());
    }
    if (_audioSettingsBox.count() == 0) {
      _audioSettingsBox.put(AudioSettings());
    }
  }

  AudioSettings getAudioSettings() {
    return _audioSettingsBox.getAll().first;
  }

  void updateAudioSettings(AudioSettings settings) {
    _audioSettingsBox.put(settings);
  }

  void resetAudioSettings() {
    _audioSettingsBox.removeAll();
    _audioSettingsBox.put(AudioSettings());
  }

  AppSettings getAppSettings() {
    return _appSettingsBox.getAll().first;
  }

  void updateAppSettings(AppSettings settings) {
     _appSettingsBox.put(settings);
  }

  void resetAppSettings() async {
    _appSettingsBox.removeAll();
    _appSettingsBox.put(AppSettings());
  }
}