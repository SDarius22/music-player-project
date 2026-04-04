import 'package:music_player_frontend/core/database/object_box_store.dart';
import 'package:music_player_frontend/core/database/objectbox.g.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';

class ObjectBoxSettingsRepository implements SettingsRepository {
  Box<AppSettings> get _appSettingsBox => ObjectBox.store.box<AppSettings>();

  Box<AudioSettings> get _audioSettingsBox =>
      ObjectBox.store.box<AudioSettings>();

  @override
  AudioSettings saveAudioSettings(AudioSettings settings) {
    settings.id = _audioSettingsBox.put(settings);
    return settings;
  }

  @override
  AudioSettings getAudioSettings() {
    if (_audioSettingsBox.isEmpty()) {
      saveAudioSettings(AudioSettings());
    }
    return _audioSettingsBox.query().build().findFirst()!;
  }

  @override
  AppSettings saveAppSettings(AppSettings settings) {
    settings.id = _appSettingsBox.put(settings);
    return settings;
  }

  @override
  AppSettings getAppSettings() {
    if (_appSettingsBox.isEmpty()) {
      saveAppSettings(AppSettings());
    }
    return _appSettingsBox.query().build().findFirst()!;
  }
}
