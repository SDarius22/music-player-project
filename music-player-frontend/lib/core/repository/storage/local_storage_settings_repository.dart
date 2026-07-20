import 'dart:convert';

import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:web/web.dart';

class LocalStorageSettingsRepository implements SettingsRepository {
  static const _appKey = 'settings.app.v1';
  static const _audioKey = 'settings.audio.v1';

  LocalStorageSettingsRepository();

  @override
  AppSettings getAppSettings() {
    final raw = window.localStorage.getItem(_appKey);
    if (raw == null || raw.isEmpty) {
      return saveAppSettings(AppSettings());
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final appSettings = AppSettings.fromJson(json);
    return appSettings;
  }

  @override
  AudioSettings getAudioSettings() {
    final raw = window.localStorage.getItem(_audioKey);
    if (raw == null || raw.isEmpty) {
      return saveAudioSettings(AudioSettings());
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final audioSettings = AudioSettings.fromJson(json);
    return audioSettings;
  }

  @override
  AppSettings saveAppSettings(AppSettings settings) {
    window.localStorage.setItem(_appKey, jsonEncode(settings.toJson()));
    return settings;
  }

  @override
  AudioSettings saveAudioSettings(AudioSettings settings) {
    window.localStorage.setItem(_audioKey, jsonEncode(settings.toJson()));
    return settings;
  }

  @override
  void clearAll() {
    window.localStorage.removeItem(_appKey);
    window.localStorage.removeItem(_audioKey);
  }
}
