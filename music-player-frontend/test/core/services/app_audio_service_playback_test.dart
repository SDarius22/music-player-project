import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

import 'app_audio_service_playback_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SongService>(),
  MockSpec<SettingsService>(),
  MockSpec<PlaylistService>(),
  MockSpec<AuthService>(),
  MockSpec<PlaybackRestClient>(),
  MockSpec<AudioPlayer>(),
])
void main() {
  late MockSongService mockSongService;
  late MockSettingsService mockSettingsService;
  late MockPlaylistService mockPlaylistService;
  late MockAuthService mockAuthService;
  late MockPlaybackRestClient mockPlaybackRestService;
  late MockAudioPlayer mockAudioPlayer;
  late AppAudioService service;

  setUp(() async {
    mockSongService = MockSongService();
    mockSettingsService = MockSettingsService();
    mockPlaylistService = MockPlaylistService();
    mockAuthService = MockAuthService();
    mockPlaybackRestService = MockPlaybackRestClient();
    mockAudioPlayer = MockAudioPlayer();
    when(mockSettingsService.updateAudioSettings(any)).thenAnswer((_) async {});

    service = AppAudioService(
      mockSongService,
      mockSettingsService,
      mockPlaylistService,
      mockAuthService,
      (_) => throw UnimplementedError(),
      mockPlaybackRestService,
      audioPlayer: mockAudioPlayer,
    );
  });

  group('basic playback setting interactions', () {
    test('updateSliderInSeconds forwards updated settings', () async {
      service.updateSliderInSeconds(42);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(
                mockSettingsService.updateAudioSettings(captureAny),
              ).captured.last
              as AudioSettings;
      expect(captured.sliderInSeconds, 42);
    });

    test('likeCurrentSong toggles liked state and persists update', () async {
      final song = Song('hash')..likedByUser = false;
      service.currentSong = song;
      when(mockSongService.updateSong(song)).thenAnswer((_) async {});

      await service.likeCurrentSong();

      expect(song.likedByUser, isTrue);
      verify(mockSongService.updateSong(song)).called(1);
    });

    test('setAutoPlay persists updated audio settings', () async {
      await service.setAutoPlay(true);

      final captured =
          verify(
                mockSettingsService.updateAudioSettings(captureAny),
              ).captured.last
              as AudioSettings;
      expect(captured.autoPlay, isTrue);
    });
  });
}
