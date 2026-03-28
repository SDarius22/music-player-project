import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

import 'settings_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<SettingsRepository>()])
void main() {
  late MockSettingsRepository mockRepo;
  late SettingsService service;

  setUp(() {
    mockRepo = MockSettingsRepository();
    service = SettingsService(mockRepo);
  });

  group('getAudioSettings', () {
    test('delegates to repository and returns result', () {
      final settings = AudioSettings()..volume = 0.8;
      when(mockRepo.getAudioSettings()).thenReturn(settings);

      final result = service.getAudioSettings();

      expect(result, same(settings));
      verify(mockRepo.getAudioSettings()).called(1);
    });
  });

  group('getAppSettings', () {
    test('delegates to repository and returns result', () {
      final settings = AppSettings()..drawerOpen = false;
      when(mockRepo.getAppSettings()).thenReturn(settings);

      final result = service.getAppSettings();

      expect(result, same(settings));
      verify(mockRepo.getAppSettings()).called(1);
    });
  });

  group('updateAudioSettings', () {
    test('calls saveAudioSettings on repository', () {
      final settings = AudioSettings()..speed = 1.5;
      when(mockRepo.saveAudioSettings(settings)).thenReturn(settings);

      service.updateAudioSettings(settings);

      verify(mockRepo.saveAudioSettings(settings)).called(1);
    });
  });

  group('updateAppSettings', () {
    test('calls saveAppSettings on repository', () {
      final settings = AppSettings()..firstTime = false;
      when(mockRepo.saveAppSettings(settings)).thenReturn(settings);

      service.updateAppSettings(settings);

      verify(mockRepo.saveAppSettings(settings)).called(1);
    });
  });
}
