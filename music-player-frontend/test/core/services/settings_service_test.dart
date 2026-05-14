import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';

import 'settings_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<SettingsRepository>()])
class FakePlaybackRestClient extends PlaybackRestClient {
  FakePlaybackRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  PlaybackStateDto? playbackToReturn;
  PlaybackStateDto? savedState;
  bool throwOnGet = false;
  bool throwOnSave = false;

  @override
  Future<PlaybackStateDto?> getPlaybackState() async {
    if (throwOnGet) throw Exception('get failed');
    return playbackToReturn;
  }

  @override
  Future<void> savePlaybackState(PlaybackStateDto state) async {
    if (throwOnSave) throw Exception('save failed');
    savedState = state;
  }
}

void main() {
  late MockSettingsRepository mockRepo;
  late FakePlaybackRestClient fakePlaybackClient;
  late SettingsService service;

  setUp(() {
    mockRepo = MockSettingsRepository();
    fakePlaybackClient = FakePlaybackRestClient();
    service = SettingsService(mockRepo, fakePlaybackClient);

    when(mockRepo.saveAudioSettings(any)).thenAnswer(
      (invocation) => invocation.positionalArguments.first as AudioSettings,
    );
    when(mockRepo.saveAppSettings(any)).thenAnswer(
      (invocation) => invocation.positionalArguments.first as AppSettings,
    );
  });

  group('getAudioSettings', () {
    test('returns cached server playback values when available', () async {
      final localSettings =
          AudioSettings()
            ..sliderInSeconds = 1
            ..shuffle = false
            ..repeat = false;
      when(mockRepo.getAudioSettings()).thenReturn(localSettings);
      fakePlaybackClient.playbackToReturn = const PlaybackStateDto(
        positionSeconds: 45,
        shuffle: true,
        repeat: true,
      );

      final result = await service.getAudioSettings();

      expect(result.sliderInSeconds, 45);
      expect(result.shuffle, isTrue);
      expect(result.repeat, isTrue);
      verify(mockRepo.saveAudioSettings(any)).called(1);
    });

    test('falls back to repository when server state is unavailable', () async {
      final settings = AudioSettings()..volume = 0.8;
      when(mockRepo.getAudioSettings()).thenReturn(settings);

      final result = await service.getAudioSettings();

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
    test(
      'saves remotely when settings changed and always saves locally',
      () async {
        final existing =
            AudioSettings()
              ..sliderInSeconds = 1
              ..repeat = false
              ..shuffle = false;
        final updated =
            AudioSettings()
              ..sliderInSeconds = 7
              ..repeat = true
              ..shuffle = true;
        when(mockRepo.getAudioSettings()).thenReturn(existing);

        await service.updateAudioSettings(updated);

        expect(fakePlaybackClient.savedState, isNotNull);
        expect(fakePlaybackClient.savedState!.positionSeconds, 7);
        expect(fakePlaybackClient.savedState!.repeat, isTrue);
        expect(fakePlaybackClient.savedState!.shuffle, isTrue);
        verify(mockRepo.saveAudioSettings(updated)).called(1);
      },
    );

    test('still saves locally when remote update throws', () async {
      final existing = AudioSettings();
      final updated = AudioSettings()..repeat = true;
      fakePlaybackClient.throwOnSave = true;
      when(mockRepo.getAudioSettings()).thenReturn(existing);

      await service.updateAudioSettings(updated);

      verify(mockRepo.saveAudioSettings(updated)).called(1);
    });

    test(
      'autoPlay-only change saves locally without remote playback save',
      () async {
        final existing =
            AudioSettings()
              ..sliderInSeconds = 11
              ..repeat = false
              ..shuffle = true
              ..autoPlay = false;
        final updated =
            AudioSettings()
              ..sliderInSeconds = 11
              ..repeat = false
              ..shuffle = true
              ..autoPlay = true;
        when(mockRepo.getAudioSettings()).thenReturn(existing);

        await service.updateAudioSettings(updated);

        expect(fakePlaybackClient.savedState, isNull);
        verify(mockRepo.saveAudioSettings(updated)).called(1);
      },
    );
  });

  group('updateAppSettings', () {
    test('calls saveAppSettings on repository', () {
      final settings = AppSettings()..firstTime = false;

      service.updateAppSettings(settings);

      verify(mockRepo.saveAppSettings(settings)).called(1);
    });
  });
}
