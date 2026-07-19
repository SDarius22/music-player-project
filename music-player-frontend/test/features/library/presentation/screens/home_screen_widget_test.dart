import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/entities/user.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/song_provider.dart';
import 'package:music_player_frontend/features/auth/presentation/providers/user_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:music_player_frontend/shared/presentation/tiling/grid_tile.dart';
import 'package:music_player_frontend/features/library/presentation/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _FakeAppStateProvider implements AbstractAppStateProvider {
  @override
  final ValueNotifier<int> refreshRequestNotifier = ValueNotifier(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSongProvider extends ChangeNotifier implements SongProvider {
  int jumpBackFetches = 0;
  int recommendationFetches = 0;
  int rediscoverFetches = 0;

  @override
  Future<List<Song>> fetchJumpBackSongs() async {
    jumpBackFetches++;
    return [_song('jump-$jumpBackFetches', 'Jump $jumpBackFetches')];
  }

  @override
  Future<List<Song>> fetchRecommendedSongs() async {
    recommendationFetches++;
    return [
      _song(
        'recommended-$recommendationFetches',
        'Recommended $recommendationFetches',
      ),
    ];
  }

  @override
  Future<List<Song>> fetchRediscoverSongs() async {
    rediscoverFetches++;
    return [
      _song('rediscover-$rediscoverFetches', 'Rediscover $rediscoverFetches'),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  _FakeUserProvider(this._currentUser);

  final User? _currentUser;

  @override
  User? get currentUser => _currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioProvider extends ChangeNotifier implements AudioProvider {
  final queueCalls = <({List<Song> songs, Song selected})>[];

  @override
  Song? get currentSong => null;

  @override
  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    queueCalls.add((songs: songs, selected: song));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCoverService implements CoverService {
  @override
  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) {
    return Container(color: Colors.black);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song _song(String hash, String name) {
  return Song(hash)
    ..name = name
    ..durationInSeconds = 180
    ..fullyLoaded = true;
}

Widget _wrapHome({
  required _FakeAppStateProvider appStateProvider,
  required _FakeSongProvider songProvider,
  required _FakeUserProvider userProvider,
  required _FakeAudioProvider audioProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AbstractAppStateProvider>.value(value: appStateProvider),
      ChangeNotifierProvider<SongProvider>.value(value: songProvider),
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      Provider<AudioProvider>.value(value: audioProvider),
      Provider<CoverService>.value(value: _FakeCoverService()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MusicPlayerTheme.getTheme(),
      builder:
          (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: [
              const Breakpoint(start: 0, end: 599, name: MOBILE),
              const Breakpoint(start: 600, end: 1024, name: TABLET),
              const Breakpoint(start: 1025, end: 1920, name: DESKTOP),
            ],
          ),
      home: const HomeScreen(),
    ),
  );
}

void main() {
  Provider.debugCheckInvalidValueType = null;

  group('HomeScreen UI', () {
    testWidgets('renders library sections and queues tapped recommendations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appStateProvider = _FakeAppStateProvider();
      final songProvider = _FakeSongProvider();
      final audioProvider = _FakeAudioProvider();

      await tester.pumpWidget(
        _wrapHome(
          appStateProvider: appStateProvider,
          songProvider: songProvider,
          userProvider: _FakeUserProvider(
            const User(email: 'tester@example.com'),
          ),
          audioProvider: audioProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('tester'), findsOneWidget);
      expect(find.text('Jump back in'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.text('Rediscover'), findsOneWidget);
      expect(find.text('Recommended 1'), findsWidgets);

      final recommendedTile =
          find
              .ancestor(
                of: find.text('Recommended 1').last,
                matching: find.byType(CustomGridTile),
              )
              .first;

      await tester.ensureVisible(recommendedTile);
      await tester.tap(recommendedTile);
      await tester.pumpAndSettle();

      expect(audioProvider.queueCalls, hasLength(1));
      expect(
        audioProvider.queueCalls.single.selected.getName(),
        'Recommended 1',
      );
      expect(audioProvider.queueCalls.single.songs.map((s) => s.getName()), [
        'Recommended 1',
      ]);
    });

    testWidgets('global refresh notifier refetches home sections', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appStateProvider = _FakeAppStateProvider();
      final songProvider = _FakeSongProvider();

      await tester.pumpWidget(
        _wrapHome(
          appStateProvider: appStateProvider,
          songProvider: songProvider,
          userProvider: _FakeUserProvider(null),
          audioProvider: _FakeAudioProvider(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jump 1'), findsOneWidget);
      expect(songProvider.jumpBackFetches, 1);
      expect(songProvider.recommendationFetches, 1);
      expect(songProvider.rediscoverFetches, 1);

      appStateProvider.refreshRequestNotifier.value++;
      await tester.pumpAndSettle();

      expect(find.text('Jump 2'), findsOneWidget);
      expect(find.text('Jump 1'), findsNothing);
      expect(songProvider.jumpBackFetches, 2);
      expect(songProvider.recommendationFetches, 2);
      expect(songProvider.rediscoverFetches, 2);
    });
  });
}
