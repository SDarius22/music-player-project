import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/playback_source_selection.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playback_rest_client.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/settings_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/p2p/p2p_chunked_source.dart';

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
      (_) => _FakeChunkService(),
      mockPlaybackRestService,
      audioPlayer: mockAudioPlayer,
      createAudioPlayer: () => mockAudioPlayer,
    );
  });

  group('basic playback setting interactions', () {
    test(
      'remote fallback uses associated asset, not a local encoding hash',
      () {
        final local =
            Song('local-encoding')
              ..localSourceKey = 'android:42'
              ..potentialRemoteHashes = ['server-encoding'];
        expect(
          PlaybackSourceSelection.remote(local, 'fallback').remoteAssetHash,
          'server-encoding',
        );
        local.potentialRemoteHashes = [];
        expect(
          PlaybackSourceSelection.remote(local, 'fallback').kind,
          PlaybackSourceKind.unavailable,
        );
      },
    );
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

    test('setRepeat persists settings and updates player loop mode', () async {
      when(mockAudioPlayer.setLoopMode(any)).thenAnswer((_) async {});

      await service.setRepeat(true);

      final captured =
          verify(
                mockSettingsService.updateAudioSettings(captureAny),
              ).captured.last
              as AudioSettings;
      expect(captured.repeat, isTrue);
      verify(mockAudioPlayer.setLoopMode(LoopMode.one)).called(1);
    });

    test('setShuffle is no-op when value does not change', () async {
      await service.setShuffle(false);

      verifyNever(mockSettingsService.updateAudioSettings(any));
    });

    test('getCurrentSongPeerCount is zero for local song', () {
      service.currentSong = Song('hash')..path = '/tmp/local.mp3';

      expect(service.getCurrentSongPeerCount(), 0);
    });

    test('getCurrentSongPeerCount reads available peers for remote song', () {
      final chunkManager = _FakeChunkService(availablePeers: 4);
      final serviceWithChunkFactory = AppAudioService(
        mockSongService,
        mockSettingsService,
        mockPlaylistService,
        mockAuthService,
        (_) => chunkManager,
        mockPlaybackRestService,
        audioPlayer: mockAudioPlayer,
      );
      serviceWithChunkFactory.currentSong = Song('remote-hash');

      expect(serviceWithChunkFactory.getCurrentSongPeerCount(), 4);
    });

    test('fully cached remote song still uses the remote playback source', () {
      final chunkManager = _FakeChunkService(availablePeers: 4);
      final serviceWithChunkFactory = AppAudioService(
        mockSongService,
        mockSettingsService,
        mockPlaylistService,
        mockAuthService,
        (_) => chunkManager,
        mockPlaybackRestService,
        audioPlayer: mockAudioPlayer,
      );
      serviceWithChunkFactory.currentSong =
          Song('cached-remote')
            ..fullyCached = true
            ..cachedChunkCount = 10;

      expect(serviceWithChunkFactory.currentSong!.isLocal, isTrue);
      expect(serviceWithChunkFactory.currentSong!.hasLocalFile, isFalse);
      expect(serviceWithChunkFactory.getCurrentSongPeerCount(), 4);
    });
  });

  group('queue invariants', () {
    Future<Playlist> initService() async {
      final queuePlaylist = Playlist('Queue')..serverId = 1;
      when(
        mockSettingsService.getAudioSettings(),
      ).thenAnswer((_) async => AudioSettings());
      when(
        mockPlaylistService.getMostRecentPlayedSong(),
      ).thenAnswer((_) async => null);
      when(
        mockPlaylistService.getPlaylistByName('Queue'),
      ).thenAnswer((_) async => queuePlaylist);
      when(mockPlaylistService.addToPlaylist(any, any)).thenAnswer((inv) async {
        final pl = inv.positionalArguments[0] as Playlist;
        final songs = inv.positionalArguments[1] as List<Song>;
        for (final s in songs) {
          pl.addSong(s);
        }
        return pl;
      });
      when(mockPlaylistService.deleteFromPlaylist(any, any)).thenAnswer((
        inv,
      ) async {
        final song = inv.positionalArguments[0] as Song;
        final pl = inv.positionalArguments[1] as Playlist;
        pl.removeSong(song);
      });
      when(mockAudioPlayer.setVolume(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.setSpeed(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.setLoopMode(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.stop()).thenAnswer((_) async {});
      when(mockAudioPlayer.play()).thenAnswer((_) async {});
      when(
        mockAudioPlayer.setAudioSource(
          any,
          initialPosition: anyNamed('initialPosition'),
          preload: anyNamed('preload'),
          initialIndex: anyNamed('initialIndex'),
        ),
      ).thenAnswer((_) async => null);

      await service.initializeAppAudio();
      return queuePlaylist;
    }

    test('loading fetched metadata does not replace queued identity', () async {
      await initService();
      final queued = Song('remote')..name = 'Queued';
      final fetched =
          Song('remote')
            ..name = 'Fetched metadata'
            ..fullyLoaded = true;
      when(
        mockSongService.fullyFetchSong(queued),
      ).thenAnswer((_) async => fetched);
      when(
        mockSongService.resolvePlaybackSource(queued),
      ).thenReturn(PlaybackSourceSelection.remote(queued, 'test remote'));
      when(mockSongService.updateSong(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(mockAudioPlayer.position).thenReturn(Duration.zero);
      when(mockAudioPlayer.duration).thenReturn(const Duration(seconds: 120));

      await service.setQueueAndPlay([queued], queued);

      expect(service.normalQueue, [same(queued)]);
      expect(service.currentSong, same(queued));
      expect(service.currentSong!.name, 'Fetched metadata');
      expect(service.queue.map((song) => song.getHash()), ['remote']);
    });

    test(
      'failed local source load falls back once to the remote source',
      () async {
        await initService();
        final queued = Song('remote')..name = 'Queued';
        when(
          mockSongService.fullyFetchSong(queued),
        ).thenAnswer((_) async => queued);
        when(mockSongService.resolvePlaybackSource(queued)).thenReturn(
          const PlaybackSourceSelection(
            kind: PlaybackSourceKind.local,
            strength: SourceMatchStrength.metadata,
            sourceKey: 'local-key',
            sourceUri: '/local/queued.mp3',
            reason: 'test local',
          ),
        );
        when(mockSongService.updateSong(any)).thenAnswer((_) async {});
        when(mockAudioPlayer.processingState).thenReturn(ProcessingState.ready);
        when(mockAudioPlayer.position).thenReturn(Duration.zero);
        when(mockAudioPlayer.duration).thenReturn(const Duration(seconds: 120));
        var attempts = 0;
        when(
          mockAudioPlayer.setAudioSource(
            any,
            initialPosition: anyNamed('initialPosition'),
            preload: anyNamed('preload'),
            initialIndex: anyNamed('initialIndex'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw PlayerException(0, 'local failed', 0);
          return;
        });

        await service.setQueueAndPlay([queued], queued);

        expect(attempts, 2);
        final sources =
            verify(
              mockAudioPlayer.setAudioSource(
                captureAny,
                initialPosition: anyNamed('initialPosition'),
                preload: anyNamed('preload'),
                initialIndex: anyNamed('initialIndex'),
              ),
            ).captured;
        expect((sources.first as UriAudioSource).uri.path, '/local/queued.mp3');
        expect(sources[1], isA<P2PChunkedAudioSource>());
        expect((sources[1] as P2PChunkedAudioSource).fileHash, 'remote');
        expect(service.currentSong, same(queued));
        expect(service.normalQueue, [same(queued)]);
      },
    );

    test('player error rejects local source and preserves position', () async {
      final errors = StreamController<PlayerException>.broadcast();
      addTearDown(errors.close);
      when(mockAudioPlayer.errorStream).thenAnswer((_) => errors.stream);
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
      when(mockAudioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(mockAudioPlayer.position).thenReturn(const Duration(seconds: 42));
      when(mockAudioPlayer.duration).thenReturn(const Duration(seconds: 120));
      when(mockSongService.updateSong(any)).thenAnswer((_) async {});
      when(mockSongService.fullyFetchSong(any)).thenAnswer((inv) async {
        return inv.positionalArguments.single as Song;
      });
      when(mockSongService.resolvePlaybackSource(any)).thenReturn(
        const PlaybackSourceSelection(
          kind: PlaybackSourceKind.local,
          strength: SourceMatchStrength.metadata,
          sourceKey: 'local-key',
          sourceUri: '/local/queued.mp3',
          reason: 'test local',
        ),
      );
      await initService();
      verify(mockAudioPlayer.errorStream).called(1);
      final first = Song('first');
      final second = Song('second');
      await service.setQueueAndPlay([first, second], first);

      errors.add(PlayerException(7, 'local failed', 0));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final captured =
          verify(
            mockAudioPlayer.setAudioSource(
              captureAny,
              initialPosition: captureAnyNamed('initialPosition'),
              preload: anyNamed('preload'),
              initialIndex: anyNamed('initialIndex'),
            ),
          ).captured;
      expect(service.playerInstanceVersion.value, 1);
      expect(service.currentSong?.getHash(), 'first');
      expect(service.normalQueue.map((song) => song.getHash()), [
        'first',
        'second',
      ]);
      expect(captured, contains(const Duration(seconds: 42)));
      expect(captured.whereType<P2PChunkedAudioSource>(), hasLength(1));
    });

    test(
      'removeFromQueue refuses to remove the last song so queue stays non-empty',
      () async {
        await initService();
        final song =
            Song('only')
              ..name = 'Only'
              ..path = '/tmp/only.mp3';

        await service.addToQueue([song]);
        expect(service.normalQueue, hasLength(1));

        await service.removeFromQueue(song);

        expect(service.normalQueue, hasLength(1));
        expect(service.normalQueue.single.getHash(), 'only');
        verifyNever(mockPlaylistService.deleteFromPlaylist(any, any));
      },
    );

    test(
      'removeFromQueue removes a non-current song when more than one remains',
      () async {
        await initService();
        final a =
            Song('a')
              ..name = 'A'
              ..path = '/tmp/a.mp3';
        final b =
            Song('b')
              ..name = 'B'
              ..path = '/tmp/b.mp3';

        await service.addToQueue([a, b]);
        expect(service.normalQueue, hasLength(2));

        await service.removeFromQueue(b);

        expect(service.normalQueue, hasLength(1));
        expect(service.normalQueue.single.getHash(), 'a');
        verify(mockPlaylistService.deleteFromPlaylist(b, any)).called(1);
      },
    );

    test(
      'removeFromQueue keeps the queue non-empty even when removing current song',
      () async {
        await initService();
        final only =
            Song('only')
              ..name = 'Only'
              ..path = '/tmp/only.mp3';
        await service.addToQueue([only]);
        service.currentSong = only;

        await service.removeFromQueue(only);

        expect(service.normalQueue, hasLength(1));
      },
    );
  });

  group('retry-if-stuck', () {
    test(
      '_retryIfStuck reloads at the current position when playback stalls',
      () {
        fakeAsync((async) {
          final fakeChunkService = _FakeChunkService();
          final retryService = AppAudioService(
            mockSongService,
            mockSettingsService,
            mockPlaylistService,
            mockAuthService,
            (_) => fakeChunkService,
            mockPlaybackRestService,
            audioPlayer: mockAudioPlayer,
          );

          final queuePlaylist = Playlist('Queue')..serverId = 1;
          when(
            mockSettingsService.getAudioSettings(),
          ).thenAnswer((_) async => AudioSettings());
          when(
            mockPlaylistService.getMostRecentPlayedSong(),
          ).thenAnswer((_) async => null);
          when(
            mockPlaylistService.getPlaylistByName('Queue'),
          ).thenAnswer((_) async => queuePlaylist);
          when(mockPlaylistService.addToPlaylist(any, any)).thenAnswer((
            inv,
          ) async {
            final pl = inv.positionalArguments[0] as Playlist;
            final songs = inv.positionalArguments[1] as List<Song>;
            for (final s in songs) {
              pl.addSong(s);
            }
            return pl;
          });
          when(mockAudioPlayer.setVolume(any)).thenAnswer((_) async {});
          when(mockAudioPlayer.setSpeed(any)).thenAnswer((_) async {});
          when(mockAudioPlayer.setLoopMode(any)).thenAnswer((_) async {});
          when(mockAudioPlayer.stop()).thenAnswer((_) async {});
          when(mockAudioPlayer.play()).thenAnswer((_) async {});
          when(
            mockAudioPlayer.setAudioSource(
              any,
              initialPosition: anyNamed('initialPosition'),
              preload: anyNamed('preload'),
              initialIndex: anyNamed('initialIndex'),
            ),
          ).thenAnswer((_) async => null);
          when(mockAudioPlayer.playing).thenReturn(true);
          when(
            mockAudioPlayer.processingState,
          ).thenReturn(ProcessingState.ready);
          when(
            mockAudioPlayer.position,
          ).thenReturn(const Duration(seconds: 42));
          when(mockAudioPlayer.duration).thenReturn(const Duration(minutes: 3));

          unawaited(retryService.initializeAppAudio());
          async.flushMicrotasks();

          final song =
              Song('stuck-remote')
                ..name = 'Stuck'
                ..durationInSeconds = 180;
          unawaited(retryService.addToQueue([song]));
          async.flushMicrotasks();
          retryService.currentSong = song;

          unawaited(retryService.play());
          // Drive the polling loop past the stuck threshold (3 ticks of 500ms).
          async.elapse(const Duration(milliseconds: 1700));
          async.flushMicrotasks();

          final captured =
              verify(
                mockAudioPlayer.setAudioSource(
                  any,
                  initialPosition: captureAnyNamed('initialPosition'),
                  preload: anyNamed('preload'),
                  initialIndex: anyNamed('initialIndex'),
                ),
              ).captured;

          expect(captured, isNotEmpty);
          expect(captured.first, const Duration(seconds: 42));
        });
      },
    );
  });
}

class _FakeChunkService extends Fake implements ChunkService {
  _FakeChunkService({this.availablePeers = 0});

  final int availablePeers;
  final ValueNotifier<int> _peerStateNotifier = ValueNotifier<int>(0);

  @override
  int get availablePeerCount => availablePeers;

  @override
  ValueNotifier<int> get peerStateVersionNotifier => _peerStateNotifier;

  @override
  void configureSongInfo(
    String songName,
    void Function(ChunkStat)? onFullyReceived,
  ) {}

  @override
  void flushStats() {}

  @override
  bool get isReady => false;

  @override
  Future<void> loadManifest() async {}

  @override
  int get totalChunks => 0;

  @override
  Future<void> prefetchChunk(int index) async {}
}
