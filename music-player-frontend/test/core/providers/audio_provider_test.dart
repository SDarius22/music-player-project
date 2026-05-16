import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

import '../services/app_audio_service_playback_test.mocks.dart';

class _FakeFileService extends Fake implements AbstractFileService {
  @override
  List<String> get supportedAudioExtensions => const ['mp3'];

  @override
  Future<Map<String, dynamic>> retrieveSong(String path, {bool withImage = false}) {
    throw UnimplementedError();
  }

  @override
  Future<List> getAudioFiles(List<String>? songPlaces) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> getImage(path) {
    throw UnimplementedError();
  }

  @override
  Future<File> createWorkaroundFile(Song? song) async => File('');
}

class _TrackingAudioService extends AppAudioService {
  _TrackingAudioService({
    required MockSongService songService,
    required MockSettingsService settingsService,
    required MockPlaylistService playlistService,
    required MockAuthService authService,
    required MockPlaybackRestClient playbackRestService,
    required MockAudioPlayer audioPlayer,
  }) : super(
         songService,
         settingsService,
         playlistService,
         authService,
         _unusedChunkManager,
         playbackRestService,
         audioPlayer: audioPlayer,
       );

  static ChunkService _unusedChunkManager(String _) =>
      throw UnimplementedError();

  int playCalls = 0;
  int pauseCalls = 0;
  int skipPreviousCalls = 0;
  int skipNextCalls = 0;
  int stopCalls = 0;
  final List<Duration> seekCalls = [];
  final List<double> volumeCalls = [];
  final List<double> speedCalls = [];
  final List<bool> repeatCalls = [];
  final List<bool> shuffleCalls = [];
  final List<bool> autoPlayCalls = [];

  void seedSettings({
    required bool repeat,
    required bool shuffle,
    required bool autoPlay,
    required double volume,
  }) {
    currentAudioSettings.repeat = repeat;
    currentAudioSettings.shuffle = shuffle;
    currentAudioSettings.autoPlay = autoPlay;
    currentAudioSettings.volume = volume;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> skipToPrevious() async {
    skipPreviousCalls++;
  }

  @override
  Future<void> skipToNext() async {
    skipNextCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  void setVolume(double volume) {
    volumeCalls.add(volume);
  }

  @override
  void setPlaybackSpeed(double speed) {
    speedCalls.add(speed);
  }

  @override
  Future<void> setRepeat(bool repeat) async {
    repeatCalls.add(repeat);
  }

  @override
  Future<void> setShuffle(bool shuffle) async {
    shuffleCalls.add(shuffle);
  }

  @override
  Future<void> setAutoPlay(bool autoPlay) async {
    autoPlayCalls.add(autoPlay);
  }
}

void main() {
  group('AudioProvider', () {
    late MockSongService mockSongService;
    late MockSettingsService mockSettingsService;
    late MockPlaylistService mockPlaylistService;
    late MockAuthService mockAuthService;
    late MockPlaybackRestClient mockPlaybackRestClient;
    late MockAudioPlayer mockAudioPlayer;
    late _TrackingAudioService service;
    late AudioProvider provider;

    setUp(() {
      mockSongService = MockSongService();
      mockSettingsService = MockSettingsService();
      mockPlaylistService = MockPlaylistService();
      mockAuthService = MockAuthService();
      mockPlaybackRestClient = MockPlaybackRestClient();
      mockAudioPlayer = MockAudioPlayer();

      when(mockAudioPlayer.durationStream)
          .thenAnswer((_) => const Stream<Duration?>.empty());
      when(mockAudioPlayer.positionStream)
          .thenAnswer((_) => const Stream<Duration>.empty());
      when(mockAudioPlayer.bufferedPositionStream)
          .thenAnswer((_) => const Stream<Duration>.empty());
      when(mockAudioPlayer.playbackEventStream)
          .thenAnswer((_) => const Stream<PlaybackEvent>.empty());
      when(mockAudioPlayer.playing).thenReturn(false);
      when(mockAudioPlayer.processingState).thenReturn(ProcessingState.idle);
      when(mockAudioPlayer.position).thenReturn(Duration.zero);
      when(mockAudioPlayer.bufferedPosition).thenReturn(Duration.zero);
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});

      service = _TrackingAudioService(
        songService: mockSongService,
        settingsService: mockSettingsService,
        playlistService: mockPlaylistService,
        authService: mockAuthService,
        playbackRestService: mockPlaybackRestClient,
        audioPlayer: mockAudioPlayer,
      );
      service.seedSettings(
        repeat: true,
        shuffle: false,
        autoPlay: true,
        volume: 0.8,
      );
      provider = AudioProvider(service, _FakeFileService());
    });

    tearDown(() {
      provider.dispose();
    });

    test('initializes notifier state from audio settings', () {
      expect(provider.repeatNotifier.value, isTrue);
      expect(provider.shuffleNotifier.value, isFalse);
      expect(provider.autoPlayNotifier.value, isTrue);
      expect(provider.volumeNotifier.value, 0.8);
    });

    test('play and pause delegate to audio service', () async {
      await provider.play();
      await provider.pause();

      expect(service.playCalls, 1);
      expect(service.pauseCalls, 1);
    });

    test('skipToPrevious seeks to zero when slider is above threshold', () async {
      provider.sliderNotifier.value = 3501;

      await provider.skipToPrevious();

      expect(service.seekCalls, [Duration.zero]);
      expect(service.skipPreviousCalls, 0);
    });

    test('skipToPrevious delegates to service when slider is near start', () async {
      provider.sliderNotifier.value = 500;

      await provider.skipToPrevious();

      expect(service.skipPreviousCalls, 1);
      expect(service.seekCalls, isEmpty);
    });

    test('setters forward values to service and local notifiers', () {
      provider.setVolume(0.3);
      provider.setPlaybackSpeed(1.25);
      provider.setRepeat(false);
      provider.setShuffle(true);
      provider.setAutoPlay(false);

      expect(provider.volumeNotifier.value, 0.3);
      expect(provider.playbackSpeedNotifier.value, 1.25);
      expect(provider.repeatNotifier.value, isFalse);
      expect(provider.shuffleNotifier.value, isTrue);
      expect(provider.autoPlayNotifier.value, isFalse);
      expect(service.volumeCalls, [0.3]);
      expect(service.speedCalls, [1.25]);
      expect(service.repeatCalls, [false]);
      expect(service.shuffleCalls, [true]);
      expect(service.autoPlayCalls, [false]);
    });
  });
}



