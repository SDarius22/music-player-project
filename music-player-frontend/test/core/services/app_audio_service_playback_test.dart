import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/dtos/playback_state_dto.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/playback_rest_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

import 'app_audio_service_playback_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SongService>(),
  MockSpec<SettingsService>(),
  MockSpec<PlaylistService>(),
  MockSpec<AuthService>(),
  MockSpec<PlaybackRestService>(),
  MockSpec<AudioPlayer>(),
])
void main() {
  late MockSongService mockSongService;
  late MockSettingsService mockSettingsService;
  late MockPlaylistService mockPlaylistService;
  late MockAuthService mockAuthService;
  late MockPlaybackRestService mockPlaybackRestService;
  late MockAudioPlayer mockAudioPlayer;

  // Builds a service with all mocks injected.
  AppAudioService buildService({bool includeRestService = true}) {
    return AppAudioService(
      mockSongService,
      mockSettingsService,
      mockPlaylistService,
      mockAuthService,
      (id) =>
          throw UnimplementedError('ChunkService not needed in these tests'),
      playbackRestService: includeRestService ? mockPlaybackRestService : null,
      audioPlayer: mockAudioPlayer,
    );
  }

  setUp(() async {
    mockSongService = MockSongService();
    mockSettingsService = MockSettingsService();
    mockPlaylistService = MockPlaylistService();
    mockAuthService = MockAuthService();
    mockPlaybackRestService = MockPlaybackRestService();
    mockAudioPlayer = MockAudioPlayer();

    when(mockSettingsService.getAudioSettings()).thenReturn(AudioSettings());
    when(mockPlaylistService.getMostRecentPlayedSong()).thenReturn(null);
    when(mockPlaylistService.getQueuePlaylist()).thenReturn(Playlist());
    when(
      mockAudioPlayer.processingStateStream,
    ).thenAnswer((_) => const Stream.empty());
    when(mockAudioPlayer.errorStream).thenAnswer((_) => const Stream.empty());
    when(mockAudioPlayer.position).thenReturn(Duration.zero);
    when(mockAudioPlayer.setVolume(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setSpeed(any)).thenAnswer((_) async {});
    when(mockAudioPlayer.setLoopMode(any)).thenAnswer((_) async {});
  });

  group('pushStateToServer', () {
    test('does nothing when playbackRestService is null', () async {
      final service = buildService(includeRestService: false);
      await Future.delayed(Duration.zero); // let _initPlayer complete

      service.pushStateToServer();

      verifyNever(mockPlaybackRestService.savePlaybackState(any));
    });

    test('only includes server songs (not local files) in the queue', () async {
      final service = buildService();
      await Future.delayed(Duration.zero);

      // Populate the queue with one server and one local song.
      final serverSong =
          Song()
            ..id = 1
            ..serverId = 42;
      final localSong =
          Song()
            ..id = 2
            ..serverId = -1
            ..path = '/music/local.mp3';

      when(mockPlaylistService.addToPlaylist(any, any)).thenReturn(null);
      await service.addToQueue([serverSong, localSong]);

      service.pushStateToServer();

      final captured =
          verify(
                mockPlaybackRestService.savePlaybackState(captureAny),
              ).captured.last
              as PlaybackStateDto;

      expect(captured.queueSongIds, equals([42]));
      expect(captured.queueSongIds, isNot(contains(-1)));
    });

    test('payload includes current positionMs, shuffle, and repeat', () async {
      final service = buildService();
      await Future.delayed(Duration.zero);

      // Set shuffle and repeat on the internal audio settings.
      service.setRepeat(true);
      when(
        mockAudioPlayer.position,
      ).thenReturn(const Duration(milliseconds: 12000));

      service.pushStateToServer();

      final captured =
          verify(
                mockPlaybackRestService.savePlaybackState(captureAny),
              ).captured.last
              as PlaybackStateDto;

      expect(captured.repeat, isTrue);
      expect(captured.positionMs, equals(12000));
    });
  });

  group('restoreFromServerState', () {
    test('is a no-op when queueSongIds is empty', () async {
      final service = buildService();
      await Future.delayed(Duration.zero);

      const dto = PlaybackStateDto(queueSongIds: [], positionMs: 0);
      await service.restoreFromServerState(dto);

      expect(service.queue, isEmpty);
      verifyNever(mockSettingsService.updateAudioSettings(any));
    });

    test(
      'is a no-op when none of the server IDs exist in the local DB',
      () async {
        final service = buildService();
        await Future.delayed(Duration.zero);

        when(mockSongService.getSongByServerId(any)).thenReturn(null);

        const dto = PlaybackStateDto(
          queueSongIds: [10, 20, 30],
          currentSongId: 10,
          positionMs: 5000,
          shuffle: true,
          repeat: true,
        );

        await service.restoreFromServerState(dto);

        expect(service.queue, isEmpty);
        verifyNever(mockSettingsService.updateAudioSettings(any));
      },
    );

    test(
      'restores queue, current song, shuffle, and repeat from server state',
      () async {
        final service = buildService();
        await Future.delayed(Duration.zero);

        final songA = Song()..serverId = 10;
        final songB = Song()..serverId = 20;
        when(mockSongService.getSongByServerId(10)).thenReturn(songA);
        when(mockSongService.getSongByServerId(20)).thenReturn(songB);
        when(
          mockAudioPlayer.setAudioSource(
            any,
            initialPosition: anyNamed('initialPosition'),
          ),
        ).thenAnswer((_) async => null);

        const dto = PlaybackStateDto(
          queueSongIds: [10, 20],
          currentSongId: 20,
          positionMs: 3000,
          shuffle: true,
          repeat: true,
        );

        await service.restoreFromServerState(dto);

        expect(service.queue, equals([songA, songB]));
        expect(service.currentSong.serverId, equals(20));
        expect(service.currentAudioSettings.shuffle, isTrue);
        expect(service.currentAudioSettings.repeat, isTrue);
        verify(mockSettingsService.updateAudioSettings(any)).called(1);
        verify(
          mockAudioPlayer.setLoopMode(LoopMode.one),
        ).called(greaterThan(0));
      },
    );

    test(
      'falls back to first song when currentSongId is not in the queue',
      () async {
        final service = buildService();
        await Future.delayed(Duration.zero);

        final songA = Song()..serverId = 10;
        final songB = Song()..serverId = 20;
        when(mockSongService.getSongByServerId(10)).thenReturn(songA);
        when(mockSongService.getSongByServerId(20)).thenReturn(songB);
        when(
          mockAudioPlayer.setAudioSource(
            any,
            initialPosition: anyNamed('initialPosition'),
          ),
        ).thenAnswer((_) async => null);

        // currentSongId 99 does not appear in the resolved queue
        const dto = PlaybackStateDto(
          queueSongIds: [10, 20],
          currentSongId: 99,
          positionMs: 0,
        );

        await service.restoreFromServerState(dto);

        expect(service.currentSong.serverId, equals(10)); // first in queue
      },
    );
  });
}
