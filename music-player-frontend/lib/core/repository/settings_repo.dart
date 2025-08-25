import 'package:music_player_frontend/core/database/objectBox.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';

class SettingsRepo {
  get audioSettingsBox => ObjectBox.store.box<AudioSettings>();
  get appSettingsBox => ObjectBox.store.box<AppSettings>();

  SettingsRepo() {
    initAudioSettings();
    initAppSettings();
  }

  void addAudioSettings(AudioSettings settings)  {
     audioSettingsBox.put(settings);
  }

  AudioSettings getAudioSettings() {
    return audioSettingsBox._query().build().findFirst();
  }

  int getAudioSettingsCount() {
    return audioSettingsBox.count();
  }

  void updateAudioSettings(AudioSettings settings)  {
     audioSettingsBox.put(settings);
  }

  void deleteAudioSettings(AudioSettings settings)  {
     audioSettingsBox.remove(settings.id);
  }

  void resetAudioSettings()  {
     audioSettingsBox.removeAll();
     addAudioSettings(AudioSettings());
  }

  void initAudioSettings()  {
    if (getAudioSettingsCount() == 0) {
       addAudioSettings(AudioSettings());
    }
  }

  void addAppSettings(AppSettings settings)  {
     appSettingsBox.put(settings);
  }

  AppSettings getAppSettings()  {
    return appSettingsBox._query().build().findFirst();
  }

  int getAppSettingsCount()  {
    return appSettingsBox.count();
  }

  void updateAppSettings(AppSettings settings)  {
     appSettingsBox.put(settings);
  }

  void deleteAppSettings(AppSettings settings)  {
     appSettingsBox.remove(settings.id);
  }

  void resetAppSettings()  {
     appSettingsBox.removeAll();
     addAppSettings(AppSettings());
  }

  void initAppSettings()  {
    if ( getAppSettingsCount() == 0) {
       addAppSettings(AppSettings());
    }
  }
}