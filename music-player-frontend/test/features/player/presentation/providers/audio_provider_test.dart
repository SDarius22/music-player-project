import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:just_audio/just_audio.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';

import '../../../../core/services/app_audio_service_playback_test.mocks.dart';

class _FakeFileService extends Fake implements AbstractFileService {
  Object? workaroundError;

  @override
  List<String> get supportedAudioExtensions => const ['mp3'];

  @override
  Future<Map<String, dynamic>> retrieveSong(
    String path, {
    bool withImage = false,
  }) {
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
  Future<File> createWorkaroundFile(Song? song) async {
    if (workaroundError case final error?) throw error;
    return File('');
  }
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
  final List<Song> testQueue = [];
  int addLastCalls = 0;
  int addNextCalls = 0;
  int removeCalls = 0;
  int setQueueCalls = 0;
  int setCurrentCalls = 0;
  int likeCalls = 0;

  @override
  List<Song> get queue => List.unmodifiable(testQueue);

  @override
  List<Song> get normalQueue => List.unmodifiable(testQueue);

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

  @override
  Future<void> addToQueue(List<Song> songs) async {
    addLastCalls++;
    testQueue.addAll(songs);
  }

  @override
  Future<void> addNextToQueue(List<Song> songs) async {
    addNextCalls++;
    testQueue.insertAll(0, songs);
  }

  @override
  Future<void> removeFromQueue(Song song) async {
    removeCalls++;
    testQueue.remove(song);
  }

  @override
  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    setQueueCalls++;
    testQueue
      ..clear()
      ..addAll(songs);
    currentSongNotifier.value = song;
  }

  @override
  Future<void> setCurrentSongAndPlay(Song song) async {
    setCurrentCalls++;
    currentSongNotifier.value = song;
  }

  @override
  Future<void> likeCurrentSong() async {
    likeCalls++;
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
    late _FakeFileService fileService;
    late StreamController<Duration?> durationController;
    late StreamController<Duration> positionController;
    late StreamController<Duration> bufferedController;
    late StreamController<PlaybackEvent> eventController;

    setUp(() {
      mockSongService = MockSongService();
      mockSettingsService = MockSettingsService();
      mockPlaylistService = MockPlaylistService();
      mockAuthService = MockAuthService();
      mockPlaybackRestClient = MockPlaybackRestClient();
      mockAudioPlayer = MockAudioPlayer();

      durationController = StreamController<Duration?>.broadcast();
      positionController = StreamController<Duration>.broadcast();
      bufferedController = StreamController<Duration>.broadcast();
      eventController = StreamController<PlaybackEvent>.broadcast();

      when(
        mockAudioPlayer.durationStream,
      ).thenAnswer((_) => durationController.stream);
      when(
        mockAudioPlayer.positionStream,
      ).thenAnswer((_) => positionController.stream);
      when(
        mockAudioPlayer.bufferedPositionStream,
      ).thenAnswer((_) => bufferedController.stream);
      when(
        mockAudioPlayer.playbackEventStream,
      ).thenAnswer((_) => eventController.stream);
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
      fileService = _FakeFileService();
      provider = AudioProvider(service, fileService);
    });

    tearDown(() async {
      provider.dispose();
      await durationController.close();
      await positionController.close();
      await bufferedController.close();
      await eventController.close();
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

    test(
      'skipToPrevious seeks to zero when slider is above threshold',
      () async {
        provider.sliderNotifier.value = 3501;

        await provider.skipToPrevious();

        expect(service.seekCalls, [Duration.zero]);
        expect(service.skipPreviousCalls, 0);
      },
    );

    test(
      'skipToPrevious delegates to service when slider is near start',
      () async {
        provider.sliderNotifier.value = 500;

        await provider.skipToPrevious();

        expect(service.skipPreviousCalls, 1);
        expect(service.seekCalls, isEmpty);
      },
    );

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

    test('seek, stop, next, shuffle wait, and peer count delegate', () async {
      await provider.seek(const Duration(milliseconds: 250));
      await provider.stop();
      await provider.skipToNext();
      await provider.setShuffleAndWait(true);

      expect(provider.sliderNotifier.value, 250);
      expect(service.seekCalls, [const Duration(milliseconds: 250)]);
      expect(service.stopCalls, 1);
      expect(service.skipNextCalls, 1);
      expect(service.shuffleCalls, [true]);
      expect(provider.getCurrentSongPeerCount(), 0);
    });

    test(
      'uses song duration when available and service duration otherwise',
      () async {
        expect(await provider.getDuration(), Duration.zero);
        final song = Song('song')..durationInSeconds = 42;
        service.currentSongNotifier.value = song;
        expect(await provider.getDuration(), const Duration(seconds: 42));
      },
    );

    test(
      'player streams update position, buffer, duration, and state',
      () async {
        final song = Song('song');
        service.currentSongNotifier.value = song;
        durationController.add(const Duration(seconds: 12));
        positionController.add(const Duration(milliseconds: 1500));
        bufferedController.add(const Duration(seconds: 8));
        eventController.add(PlaybackEvent());
        await Future<void>.delayed(Duration.zero);

        expect(
          provider.totalDurationNotifier.value,
          const Duration(seconds: 12),
        );
        expect(provider.sliderNotifier.value, 1500);
        expect(provider.bufferedPositionNotifier.value, 8);
        expect(provider.processingState.value, ProcessingState.idle);
        verify(mockSongService.updateSong(song)).called(1);
      },
    );

    test(
      'current-song changes update duration and queue indices safely',
      () async {
        expect(provider.currentIndexInNonShuffled, -1);
        final song = Song('song')..durationInSeconds = 9;
        service.currentSongNotifier.value = song;
        await Future<void>.delayed(Duration.zero);
        expect(provider.currentSong, song);
        expect(
          provider.totalDurationNotifier.value,
          const Duration(seconds: 9),
        );
      },
    );

    test('queue accessors and mutations delegate and notify', () async {
      final a = Song('a');
      final b = Song('b');
      service.testQueue.add(a);
      service.currentSongNotifier.value = a;
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentIndexInNonShuffled, 0);
      expect(provider.currentIndexInPlaybackQueue, 0);
      expect(provider.playbackQueue, [a]);
      expect(provider.normalQueue, [a]);

      await provider.addLastToQueue([b]);
      await provider.addNextToQueue([Song('c')]);
      await provider.removeFromQueue(b);
      await provider.setQueueAndPlay([a, b], b);
      await provider.setCurrentSongAndPlay(a);
      await provider.likeCurrentSong();

      expect(service.addLastCalls, 1);
      expect(service.addNextCalls, 1);
      expect(service.removeCalls, 1);
      expect(service.setQueueCalls, 1);
      expect(service.setCurrentCalls, 1);
      expect(service.likeCalls, 1);
    });

    test('current song notifiers are exposed', () {
      expect(provider.currentSongNotifier, same(service.currentSongNotifier));
      expect(provider.likedNotifier, same(service.likedNotifier));
      expect(
        provider.songPeerCountNotifier,
        same(service.songPeerCountNotifier),
      );
    });

    test('publishes notification metadata when cover creation fails', () async {
      fileService.workaroundError = StateError('no embedded artwork');
      final song =
          Song('remote-hash')
            ..name = 'Notification title'
            ..durationInSeconds = 123;

      service.currentSongNotifier.value = song;
      await Future<void>.delayed(Duration.zero);

      expect(provider.mediaItem.value?.id, 'remote-hash');
      expect(provider.mediaItem.value?.title, 'Notification title');
      expect(provider.mediaItem.value?.duration, const Duration(seconds: 123));
      expect(provider.mediaItem.value?.artUri, isNull);
    });

    test('clears all presented playback state when the session ends', () async {
      service.currentSongNotifier.value =
          Song('private-song')
            ..name = 'Private song'
            ..durationInSeconds = 123;
      await Future<void>.delayed(Duration.zero);
      provider.sliderNotifier.value = 9000;
      provider.bufferedPositionNotifier.value = 10;

      service.currentSongNotifier.value = null;

      expect(provider.currentSong, isNull);
      expect(provider.mediaItem.value, isNull);
      expect(provider.queue.value, isEmpty);
      expect(provider.playingNotifier.value, isFalse);
      expect(provider.processingState.value, ProcessingState.idle);
      expect(provider.sliderNotifier.value, 0);
      expect(provider.bufferedPositionNotifier.value, 0);
      expect(provider.totalDurationNotifier.value, Duration.zero);
    });

    test('accepts colors from a merged version of the current album', () async {
      final artist = Artist('local-artist', 'Artist');
      final currentAlbum = Album('local-album', 'Album')
        ..artist.target = artist;
      final remoteAlbum =
          Album('remote-album', 'Album')
            ..artist.target = Artist('remote-artist', 'Artist')
            ..remoteSourceHashes = <String>['remote-album'];
      final song =
          Song('song-hash')
            ..artist.target = artist
            ..album.target = currentAlbum;
      final image = image_lib.Image(width: 1, height: 1)
        ..setPixelRgba(0, 0, 255, 0, 0, 255);

      service.currentSongNotifier.value = song;
      await provider.updateColorsFromCover(
        remoteAlbum,
        Uint8List.fromList(image_lib.encodePng(image)),
      );

      expect(currentAlbum.colors, hasLength(4));
    });
  });
}
