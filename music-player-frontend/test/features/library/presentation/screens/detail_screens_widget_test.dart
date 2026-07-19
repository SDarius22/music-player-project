import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/app/state/app_state_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/album_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/song_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/selection_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/features/library/presentation/screens/album_screen.dart';
import 'package:music_player_frontend/features/library/presentation/screens/base/entity_screen.dart';
import 'package:music_player_frontend/features/library/presentation/screens/track_screen.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/shared/presentation/tiling/list_tile.dart';
import 'package:provider/provider.dart';

class _SongProvider extends Fake implements SongProvider {}

class _AlbumProvider extends Fake implements AlbumProvider {
  _AlbumProvider([this.songs = const []]);

  final List<Song> songs;

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async => PageResult(content: songs, totalPages: 1, page: page);
}

class _Audio extends Fake implements AudioProvider {
  final List<({List<Song> songs, Song selected})> plays = [];
  final List<bool> shuffleChanges = [];

  @override
  Song? get currentSong => null;

  @override
  Future<void> setQueueAndPlay(List<Song> songs, Song song) async {
    plays.add((songs: songs, selected: song));
  }

  @override
  Future<void> setShuffleAndWait(bool shuffle) async {
    shuffleChanges.add(shuffle);
  }
}

class _AppState extends Fake implements AbstractAppStateProvider {
  @override
  final innerNavigatorKey = GlobalKey<NavigatorState>();
}

class _Queryable extends ChangeNotifier implements QueryableProvider {
  _Queryable(this.result, {this.shouldThrow = false});

  final Song? result;
  final bool shouldThrow;

  @override
  Future<Song?> fetchEntity(entity) async {
    if (shouldThrow) throw Exception('offline');
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntityDetails extends EntityScreen<_Queryable> {
  const _EntityDetails({required super.entity, required super.provider});

  @override
  Widget buildContentSection(context, entity, constraints) =>
      const Text('Content');
}

class _Cover implements CoverService {
  @override
  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) => const ColoredBox(color: Colors.black);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(
  Widget Function(BuildContext) builder, {
  AudioProvider? audio,
  AbstractAppStateProvider? appState,
  AlbumProvider? albumProvider,
}) => MultiProvider(
  providers: [
    Provider<CoverService>.value(value: _Cover()),
    ChangeNotifierProvider(create: (_) => SelectionProvider()),
    if (audio != null) Provider<AudioProvider>.value(value: audio),
    if (appState != null)
      Provider<AbstractAppStateProvider>.value(value: appState),
    if (albumProvider != null)
      Provider<AlbumProvider>.value(value: albumProvider),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: Builder(builder: builder)),
  ),
);

void main() {
  Provider.debugCheckInvalidValueType = null;

  testWidgets('track details and app bar render complete metadata', (
    tester,
  ) async {
    final artist = Artist('artist', 'The Artist');
    final album = Album('album', 'The Album');
    final song =
        Song('song')
          ..name = 'The Track'
          ..durationInSeconds = 125
          ..year = 2025
          ..likedByUser = true;
    song.artist.target = artist;
    song.album.target = album;
    final screen = TrackScreen(
      entity: song,
      provider: _SongProvider(),
      liked: true,
    );

    await tester.pumpWidget(
      _host(
        (context) => Column(
          children: [
            screen.buildAppBar(context, song),
            Expanded(
              child: screen.buildContentSection(
                context,
                song,
                const BoxConstraints(maxWidth: 800, maxHeight: 600),
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('The Track'), findsWidgets);
    expect(find.text('The Artist'), findsOneWidget);
    expect(find.text('The Album'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.textContaining('2 minutes'), findsOneWidget);
    expect(find.byTooltip('Like'), findsOneWidget);
  });

  testWidgets('track details show unknown optional metadata', (tester) async {
    final song = Song('song')..name = 'Minimal';
    final screen = TrackScreen(entity: song, provider: _SongProvider());
    await tester.pumpWidget(
      _host(
        (context) => screen.buildContentSection(
          context,
          song,
          const BoxConstraints(maxWidth: 800, maxHeight: 600),
        ),
      ),
    );
    expect(find.text('Unknown Artist'), findsOneWidget);
    expect(find.text('Unknown Album'), findsOneWidget);
    expect(find.text('Unknown year'), findsOneWidget);
  });

  testWidgets('album app bar renders and empty play actions are safe', (
    tester,
  ) async {
    final album = Album('album', 'Empty Album');
    final screen = AlbumScreen(entity: album, provider: _AlbumProvider());
    await tester.pumpWidget(
      _host((context) => screen.buildAppBar(context, album)),
    );
    expect(find.text('Empty Album'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('entity screen resolves details and builds both layouts', (
    tester,
  ) async {
    final original = Song('song')..name = 'Original';
    final detailed = Song('song')..name = 'Detailed';
    final screen = _EntityDetails(
      entity: original,
      provider: _Queryable(detailed),
    );
    await tester.pumpWidget(_host((_) => screen));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Detailed'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        (context) => screen.buildCompactBody(
          context,
          detailed,
          const BoxConstraints(maxWidth: 400, maxHeight: 600),
        ),
      ),
    );
    expect(find.text('Content'), findsOneWidget);
    await tester.pumpWidget(
      _host(
        (context) => screen.buildExpandedBody(
          context,
          detailed,
          const BoxConstraints(maxWidth: 900, maxHeight: 600),
        ),
      ),
    );
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('entity screen falls back when detail loading fails', (
    tester,
  ) async {
    final original = Song('song')..name = 'Original';
    await tester.pumpWidget(
      _host(
        (_) => _EntityDetails(
          entity: original,
          provider: _Queryable(null, shouldThrow: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Original'), findsOneWidget);
  });

  testWidgets('album app bar plays in track order and enables shuffle', (
    tester,
  ) async {
    final second =
        Song('second')
          ..name = 'Second'
          ..trackNumber = 2;
    final first =
        Song('first')
          ..name = 'First'
          ..trackNumber = 1;
    final album = Album('album', 'Playable Album');
    final provider = _AlbumProvider([second, first]);
    final audio = _Audio();
    final screen = AlbumScreen(entity: album, provider: provider);

    await tester.pumpWidget(
      _host(
        (context) => screen.buildAppBar(context, album),
        audio: audio,
        appState: _AppState(),
      ),
    );

    await tester.tap(find.byTooltip('Add'));
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pump();

    expect(audio.plays, hasLength(2));
    expect(audio.plays.first.songs, [first, second]);
    expect(audio.plays.first.selected, same(first));
    expect(audio.plays.last.songs, [first, second]);
    expect(audio.plays.last.selected, isIn([first, second]));
    expect(audio.shuffleChanges, [true]);
  });

  testWidgets('album track tap plays and selection mode toggles the song', (
    tester,
  ) async {
    final song =
        Song('song')
          ..name = 'Interactive Song'
          ..fullyLoaded = true;
    final album = Album('album', 'Album');
    final provider = _AlbumProvider([song]);
    final audio = _Audio();
    late SelectionProvider selection;
    final screen = AlbumScreen(entity: album, provider: provider);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CoverService>.value(value: _Cover()),
          Provider<AudioProvider>.value(value: audio),
          ChangeNotifierProvider(
            create: (_) => selection = SelectionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => screen.buildContentSection(
                    context,
                    album,
                    const BoxConstraints(maxWidth: 900, maxHeight: 700),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byWidgetPredicate(
      (widget) => widget is CustomListTile && widget.entity == song,
    );

    await tester.tap(tile);
    await tester.pump();
    expect(audio.plays.single.selected, same(song));

    await tester.longPress(tile);
    await tester.pumpAndSettle();
    expect(selection.isSelected(song), isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(selection.isSelected(song), isFalse);
    expect(audio.plays, hasLength(1));
  });

  testWidgets('album route resolves its provider and builds the screen', (
    tester,
  ) async {
    final album = Album('route-album', 'Route Album');
    final provider = _AlbumProvider();
    await tester.pumpWidget(
      _host(
        (context) => TextButton(
          onPressed:
              () => Navigator.of(context).push(AlbumScreen.route(album: album)),
          child: const Text('open album'),
        ),
        albumProvider: provider,
      ),
    );

    await tester.tap(find.text('open album'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsOneWidget);
  });
}
