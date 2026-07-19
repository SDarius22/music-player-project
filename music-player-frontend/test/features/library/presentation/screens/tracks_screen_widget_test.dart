import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/selection_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/app/theme/music_player_theme.dart';
import 'package:music_player_frontend/shared/presentation/tiling/grid_tile.dart';
import 'package:music_player_frontend/features/library/presentation/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _FakeAppStateProvider implements AbstractAppStateProvider {
  @override
  final ValueNotifier<int> refreshRequestNotifier = ValueNotifier(0);

  @override
  final ValueNotifier<bool> shouldDisplayLocalOnly = ValueNotifier(false);

  @override
  final GlobalKey<NavigatorState> innerNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSongProvider extends ChangeNotifier implements SongProvider {
  _FakeSongProvider(this._songs);

  final List<Song> _songs;
  final fetchCalls =
      <
        ({
          String query,
          String sortField,
          bool ascending,
          bool localOnly,
          bool streamOnly,
          int page,
          int size,
        })
      >[];

  @override
  Map<String, dynamic> get sortFields => const {'Title': null, 'Year': null};

  @override
  Future<PageResult<Song>> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    bool streamOnly = false,
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
  }) async {
    fetchCalls.add((
      query: query,
      sortField: sortField,
      ascending: ascending,
      localOnly: localOnly,
      streamOnly: streamOnly,
      page: page,
      size: size,
    ));

    final normalizedQuery = query.trim().toLowerCase();
    final filtered =
        _songs.where((song) {
          if (normalizedQuery.isNotEmpty &&
              !song.name.toLowerCase().contains(normalizedQuery)) {
            return false;
          }
          if (localOnly && !song.isLocal) return false;
          if (streamOnly && !song.isAvailableToStream) return false;
          return true;
        }).toList();

    filtered.sort((a, b) {
      final result =
          sortField == 'Year'
              ? a.year.compareTo(b.year)
              : a.name.compareTo(b.name);
      return ascending ? result : -result;
    });

    final start = page * size;
    final end = (start + size).clamp(0, filtered.length);
    final content =
        start >= filtered.length ? <Song>[] : filtered.sublist(start, end);

    return PageResult<Song>(
      content: content,
      totalPages: ((filtered.length + size - 1) ~/ size).clamp(1, 999999),
      page: page,
    );
  }

  @override
  Future<Song> enrichSong(Song song) async => song;

  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioProvider extends ChangeNotifier implements AudioProvider {
  final queueCalls = <({List<Song> songs, Song selected})>[];
  final nextQueueCalls = <List<Song>>[];
  final downloads = <Song>[];
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);

  Song? _currentSong;

  @override
  Song? get currentSong => _currentSong;

  @override
  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    queueCalls.add((songs: songs, selected: song));
    _currentSong = song;
    notifyListeners();
  }

  @override
  Future<void> addNextToQueue(List<Song> songs) async {
    nextQueueCalls.add(songs);
  }

  @override
  Future<void> downloadSong(Song song) async {
    downloads.add(song);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playingNotifier.value = true;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playingNotifier.value = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCoverService implements CoverService {
  @override
  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) => Container(color: Colors.black);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song _song(String hash, String name, {int year = 2026, bool local = false}) {
  return Song(hash)
    ..name = name
    ..year = year
    ..path = local ? '/tmp/$hash.mp3' : null
    ..durationInSeconds = 180
    ..fullyLoaded = true;
}

Finder _tileForText(String text) {
  return find
      .ancestor(of: find.text(text).last, matching: find.byType(CustomGridTile))
      .first;
}

Future<void> _pumpInitialTrackLoad(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 401));
  await tester.pumpAndSettle();
}

Widget _wrapTracks({
  required _FakeAppStateProvider appStateProvider,
  required _FakeSongProvider songProvider,
  required _FakeAudioProvider audioProvider,
  required SelectionProvider selectionProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AbstractAppStateProvider>.value(value: appStateProvider),
      ChangeNotifierProvider<SongProvider>.value(value: songProvider),
      ChangeNotifierProvider<SelectionProvider>.value(value: selectionProvider),
      ChangeNotifierProvider<AudioProvider>.value(value: audioProvider),
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
      home: Tracks(provider: songProvider),
    ),
  );
}

void main() {
  Provider.debugCheckInvalidValueType = null;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Tracks screen UI', () {
    testWidgets('searches, filters local-only, and reloads the track grid', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appStateProvider = _FakeAppStateProvider();
      final songProvider = _FakeSongProvider([
        _song('alpha', 'Alpha Remote'),
        _song('beta', 'Beta Local', local: true),
      ]);

      await tester.pumpWidget(
        _wrapTracks(
          appStateProvider: appStateProvider,
          songProvider: songProvider,
          audioProvider: _FakeAudioProvider(),
          selectionProvider: SelectionProvider(),
        ),
      );
      await _pumpInitialTrackLoad(tester);

      expect(find.text('Alpha Remote'), findsWidgets);
      expect(find.text('Beta Local'), findsWidgets);

      await tester.enterText(find.byType(TextFormField), 'beta');
      await tester.pump(const Duration(milliseconds: 501));
      await tester.pumpAndSettle();

      expect(songProvider.fetchCalls.last.query, 'beta');
      expect(find.text('Beta Local'), findsWidgets);
      expect(find.text('Alpha Remote'), findsNothing);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available Offline'));
      await tester.pumpAndSettle();

      expect(songProvider.fetchCalls.last.localOnly, true);
      expect(find.text('Beta Local'), findsWidgets);
      expect(find.text('Alpha Remote'), findsNothing);

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available to Stream'));
      await tester.pumpAndSettle();

      expect(songProvider.fetchCalls.last.localOnly, true);
      expect(songProvider.fetchCalls.last.streamOnly, true);
    });

    testWidgets('remote-only track menu offers download', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioProvider = _FakeAudioProvider();
      final songProvider = _FakeSongProvider([
        _song('remote', 'Remote Track'),
        _song('local', 'Local Track', local: true),
      ]);
      await tester.pumpWidget(
        _wrapTracks(
          appStateProvider: _FakeAppStateProvider(),
          songProvider: songProvider,
          audioProvider: audioProvider,
          selectionProvider: SelectionProvider(),
        ),
      );
      await _pumpInitialTrackLoad(tester);

      await tester.tap(
        find.descendant(
          of: _tileForText('Remote Track'),
          matching: find.byIcon(FluentIcons.moreVertical),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download'), findsOneWidget);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(audioProvider.downloads.map((song) => song.fileHash), ['remote']);
    });

    testWidgets('tapping a track queues the visible page and selected song', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioProvider = _FakeAudioProvider();
      final songProvider = _FakeSongProvider([
        _song('alpha', 'Alpha Track'),
        _song('beta', 'Beta Track'),
      ]);

      await tester.pumpWidget(
        _wrapTracks(
          appStateProvider: _FakeAppStateProvider(),
          songProvider: songProvider,
          audioProvider: audioProvider,
          selectionProvider: SelectionProvider(),
        ),
      );
      await _pumpInitialTrackLoad(tester);

      await tester.tap(_tileForText('Beta Track'));
      await tester.pumpAndSettle();

      expect(audioProvider.queueCalls, hasLength(1));
      expect(audioProvider.queueCalls.single.selected.getName(), 'Beta Track');
      expect(
        audioProvider.queueCalls.single.songs.map((song) => song.getName()),
        ['Alpha Track', 'Beta Track'],
      );

      await tester.tap(_tileForText('Beta Track'));
      await tester.pumpAndSettle();
      expect(audioProvider.playCalls, 1);

      await tester.tap(_tileForText('Beta Track'));
      await tester.pumpAndSettle();
      expect(audioProvider.pauseCalls, 1);
    });

    testWidgets('track menu queues next and toggles selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioProvider = _FakeAudioProvider();
      final selectionProvider = SelectionProvider();
      final songProvider = _FakeSongProvider([_song('song', 'Menu Track')]);
      await tester.pumpWidget(
        _wrapTracks(
          appStateProvider: _FakeAppStateProvider(),
          songProvider: songProvider,
          audioProvider: audioProvider,
          selectionProvider: selectionProvider,
        ),
      );
      await _pumpInitialTrackLoad(tester);

      Future<void> choose(String label) async {
        await tester.tap(
          find.descendant(
            of: _tileForText('Menu Track'),
            matching: find.byIcon(FluentIcons.moreVertical),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await choose('Add to...');
      await choose('Play Next');
      expect(audioProvider.nextQueueCalls.single.single.fileHash, 'song');

      await choose('Track Details');
      await choose('Select');
      expect(selectionProvider.selectedEntities.single.getName(), 'Menu Track');

      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selectionProvider.selectedEntities, isEmpty);
    });

    testWidgets('selection mode toggles tiles without starting playback', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioProvider = _FakeAudioProvider();
      final selectionProvider = SelectionProvider();
      final songProvider = _FakeSongProvider([
        _song('alpha', 'Alpha Track'),
        _song('beta', 'Beta Track'),
      ]);

      await tester.pumpWidget(
        _wrapTracks(
          appStateProvider: _FakeAppStateProvider(),
          songProvider: songProvider,
          audioProvider: audioProvider,
          selectionProvider: selectionProvider,
        ),
      );
      await _pumpInitialTrackLoad(tester);

      await tester.longPress(_tileForText('Alpha Track'));
      await tester.pumpAndSettle();

      expect(selectionProvider.selectedEntities.map((e) => e.getName()), [
        'Alpha Track',
      ]);

      await tester.tap(_tileForText('Beta Track'));
      await tester.pumpAndSettle();

      expect(selectionProvider.selectedEntities.map((e) => e.getName()), [
        'Alpha Track',
        'Beta Track',
      ]);
      expect(audioProvider.queueCalls, isEmpty);

      expect(find.text('2 songs selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Play Next'), findsOneWidget);
      expect(find.text('Add to'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(audioProvider.queueCalls, hasLength(1));

      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Next'));
      await tester.pumpAndSettle();
      expect(audioProvider.nextQueueCalls, hasLength(1));

      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(audioProvider.downloads, hasLength(2));

      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Selection actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selectionProvider.selectedEntities, isEmpty);
    });
  });
}
