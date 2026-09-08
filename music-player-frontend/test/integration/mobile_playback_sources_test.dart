import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/p2p/p2p_chunked_source.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/services/app_audio_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/local_track_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';

import '../core/services/app_audio_service_playback_test.mocks.dart';
import '../core/services/song_service_test.dart' show FakeSongRestClient;

// Real service composition; only transport, platform player and settings are faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppAudioService audio;
  late MockAudioPlayer player;
  late InMemoryLocalTrackRepository locals;
  late Song first;
  late Song second;
  late List<AudioSource> installed;

  setUp(() async {
    locals = InMemoryLocalTrackRepository();
    final localTracks = LocalTrackService(locals);
    final songs = InMemorySongRepository();
    first =
        Song('remote-first')
          ..name = 'First'
          ..durationInSeconds = 120
          ..fullyLoaded = true
          ..artist.target = Artist('artist', 'Artist');
    second =
        Song('remote-second')
          ..name = 'Second'
          ..durationInSeconds = 120
          ..fullyLoaded = true
          ..artist.target = Artist('artist', 'Artist');
    songs.updateSongs([first, second]);
    locals.save(
      LocalTrack(
        sourceKey: 'android:42',
        sourceUri: 'content://media/external/audio/media/42',
        potentialIdentityKey: 'candidate',
        name: 'First',
        artistName: 'Artist',
        durationInSeconds: 120,
      ),
    );
    final service = SongService(
      songs,
      InMemoryArtistRepository(),
      InMemoryAlbumRepository(),
      FakeSongRestClient(),
      localTracks,
    );
    player = MockAudioPlayer();
    installed = [];
    when(player.processingState).thenReturn(ProcessingState.ready);
    when(player.position).thenReturn(Duration.zero);
    when(player.duration).thenReturn(const Duration(seconds: 120));
    when(
      player.setAudioSource(
        any,
        initialPosition: anyNamed('initialPosition'),
        preload: anyNamed('preload'),
        initialIndex: anyNamed('initialIndex'),
      ),
    ).thenAnswer((call) async {
      installed.add(call.positionalArguments.first as AudioSource);
      return null;
    });
    final settings = MockSettingsService();
    when(settings.getAudioSettings()).thenAnswer((_) async => AudioSettings());
    final playlists = MockPlaylistService();
    final queue = Playlist('Queue');
    when(playlists.getPlaylistByName('Queue')).thenAnswer((_) async => queue);
    when(playlists.getMostRecentPlayedSong()).thenAnswer((_) async => null);
    when(
      playlists.addToPlaylist(any, any),
    ).thenAnswer((call) async => call.positionalArguments.first as Playlist);
    audio = AppAudioService(
      service,
      settings,
      playlists,
      MockAuthService(),
      (_) => _Chunks(),
      MockPlaybackRestClient(),
      audioPlayer: player,
    );
    await audio.initializeAppAudio();
  });
  tearDown(() async => audio.dispose());

  test(
    'real resolver plays unhashed content URI and falls back with queue intact',
    () async {
      var failed = false;
      when(
        player.setAudioSource(
          any,
          initialPosition: anyNamed('initialPosition'),
          preload: anyNamed('preload'),
          initialIndex: anyNamed('initialIndex'),
        ),
      ).thenAnswer((call) async {
        final source = call.positionalArguments.first as AudioSource;
        installed.add(source);
        if (!failed) {
          failed = true;
          throw PlayerException(1, 'permission revoked', 0);
        }
        return null;
      });
      await audio.setQueueAndPlay([first, second], first);
      expect((installed.first as UriAudioSource).uri.scheme, 'content');
      expect(
        (installed.last as P2PChunkedAudioSource).fileHash,
        first.fileHash,
      );
      expect(audio.normalQueue, [same(first), same(second)]);
      expect(audio.currentSong!.getHash(), first.fileHash);
      expect(locals.getAll().single.contentHash, isNull);
    },
  );

  test(
    'queued source replacement discards an older asynchronous install',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      when(
        player.setAudioSource(
          any,
          initialPosition: anyNamed('initialPosition'),
          preload: anyNamed('preload'),
          initialIndex: anyNamed('initialIndex'),
        ),
      ).thenAnswer((call) async {
        installed.add(call.positionalArguments.first as AudioSource);
        if (!started.isCompleted) {
          started.complete();
          await release.future;
        }
        return null;
      });
      final older = audio.setQueueAndPlay([first, second], first);
      await started.future;
      final newer = audio.setCurrentSongAndPlay(second);
      release.complete();
      await Future.wait([older, newer]);
      expect(audio.currentSong!.getHash(), second.fileHash);
      expect(
        (installed.last as P2PChunkedAudioSource).fileHash,
        second.fileHash,
      );
      expect(audio.normalQueue, [same(first), same(second)]);
      verify(player.play()).called(1);
    },
  );

  test(
    'multiple metadata copies do not substitute a remote queue entry',
    () async {
      locals.save(
        LocalTrack(
          sourceKey: 'android:43',
          sourceUri: 'content://media/external/audio/media/43',
          potentialIdentityKey: 'candidate',
          name: 'First',
          artistName: 'Artist',
          durationInSeconds: 120,
        ),
      );
      await audio.setQueueAndPlay([first, second], first);
      expect(installed.single, isA<P2PChunkedAudioSource>());
      expect(
        locals.getAll().every((track) => track.contentHash == null),
        isTrue,
      );
    },
  );
}

class _Chunks extends Fake implements ChunkService {
  final _version = ValueNotifier<int>(0);
  @override
  int get availablePeerCount => 0;
  @override
  ValueNotifier<int> get peerStateVersionNotifier => _version;
  @override
  void flushStats() {}
  @override
  void configureSongInfo(String name, void Function(ChunkStat)? callback) {}
}
