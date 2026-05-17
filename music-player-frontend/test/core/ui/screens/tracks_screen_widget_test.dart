import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/core/ui/screens/tracks.dart';
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
    String? filterAlbumHash,
    String? filterArtistHash,
    int? filterPlaylistId,
  }) async {
    fetchCalls.add((
      query: query,
      sortField: sortField,
      ascending: ascending,
      localOnly: localOnly,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCoverService implements CoverService {
  @override
  Widget getWidget(BaseEntity entity) => Container(color: Colors.black);

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
      await tester.pumpAndSettle();

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
      await tester.tap(find.text('Local Only'));
      await tester.pumpAndSettle();

      expect(songProvider.fetchCalls.last.localOnly, true);
      expect(find.text('Beta Local'), findsWidgets);
      expect(find.text('Alpha Remote'), findsNothing);
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
      await tester.pumpAndSettle();

      await tester.tap(_tileForText('Beta Track'));
      await tester.pumpAndSettle();

      expect(audioProvider.queueCalls, hasLength(1));
      expect(audioProvider.queueCalls.single.selected.getName(), 'Beta Track');
      expect(
        audioProvider.queueCalls.single.songs.map((song) => song.getName()),
        ['Alpha Track', 'Beta Track'],
      );
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
      await tester.pumpAndSettle();

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
    });
  });
}
