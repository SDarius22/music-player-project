import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';

class SettingsService {
  final SettingsRepository _settingsRepository;
  final PlaybackRestClient _playbackRestClient;

  SettingsService(this._settingsRepository, this._playbackRestClient);

  Future<AudioSettings> getAudioSettings() async {
    try {
      var playbackState = await _playbackRestClient.getPlaybackState();
      if (playbackState != null) {
        return _cacheAudioSettings(playbackState);
      }
    } catch (_) {
      // Ignore errors and return cached settings
    }
    return _settingsRepository.getAudioSettings();
  }

  Future<void> updateAudioSettings(AudioSettings newSettings) async {
    var existingSettings = _settingsRepository.getAudioSettings();
    if (existingSettings.sliderInSeconds == newSettings.sliderInSeconds &&
        existingSettings.repeat == newSettings.repeat &&
        existingSettings.shuffle == newSettings.shuffle) {
      _settingsRepository.saveAudioSettings(newSettings);
      return;
    }

    try {
      var playbackState = PlaybackStateDto(
        positionSeconds: newSettings.sliderInSeconds,
        repeat: newSettings.repeat,
        shuffle: newSettings.shuffle,
      );
      await _playbackRestClient.savePlaybackState(playbackState);
    } catch (_) {
      // Ignore errors and save locally
    }
    _settingsRepository.saveAudioSettings(newSettings);
  }

  AppSettings getAppSettings() {
    return _settingsRepository.getAppSettings();
  }

  void updateAppSettings(AppSettings newSettings) {
    _settingsRepository.saveAppSettings(newSettings);
  }

  AudioSettings _cacheAudioSettings(PlaybackStateDto playbackState) {
    var audioSettings = _settingsRepository.getAudioSettings();
    audioSettings.sliderInSeconds = playbackState.positionSeconds;
    audioSettings.repeat = playbackState.repeat;
    audioSettings.shuffle = playbackState.shuffle;
    return _settingsRepository.saveAudioSettings(audioSettings);
  }
}
