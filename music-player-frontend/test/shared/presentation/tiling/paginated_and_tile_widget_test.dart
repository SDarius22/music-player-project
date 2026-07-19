import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/shared/presentation/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/shared/presentation/tiling/paginated_component.dart';
import 'package:music_player_frontend/shared/presentation/tiling/tile_type.dart';
import 'package:fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class _FakeAudioProvider extends Fake implements AudioProvider {
  Song? _currentSong;

  @override
  Song? get currentSong => _currentSong;

  set currentSongValue(Song? value) {
    _currentSong = value;
  }
}

class _FakeCoverService extends Fake implements CoverService {
  @override
  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) => Container(color: Colors.black);
}

Widget _withProviders({
  required Widget child,
  required AudioProvider audioProvider,
  required CoverService coverService,
}) {
  return MultiProvider(
    providers: [
      Provider<AudioProvider>.value(value: audioProvider),
      Provider<CoverService>.value(value: coverService),
    ],
    child: MaterialApp(home: Scaffold(body: SizedBox.expand(child: child))),
  );
}

Song _song(String hash, String name) {
  return Song(hash)
    ..name = name
    ..fullyLoaded = true;
}

void main() {
  Provider.debugCheckInvalidValueType = null;

  group('PaginatedComponent and tile widgets', () {
    late _FakeAudioProvider audioProvider;
    late _FakeCoverService coverService;

    setUp(() {
      audioProvider = _FakeAudioProvider();
      coverService = _FakeCoverService();
      audioProvider.currentSongValue = null;
    });

    testWidgets('shows empty message when first page has no content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: PaginatedComponent(
            type: TileType.list,
            fetchPage:
                (_, _) async =>
                    const PageResult<Song>(content: [], totalPages: 1, page: 0),
            onTap: (_, _) async {},
            onLongPress: (_, _) {},
            isSelected: (_) => false,
            reloadToken: 0,
            emptyText: 'Nothing here',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('loads first page and fetches next page on scroll', (
      tester,
    ) async {
      final calls = <int>[];
      final page0 = List.generate(20, (i) => _song('p0-$i', 'Track $i'));
      final page1 = [_song('p1-0', 'Track next')];

      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: PaginatedComponent(
            type: TileType.list,
            itemExtent: 56,
            fetchPage: (page, _) async {
              calls.add(page);
              if (page == 0) {
                return PageResult<Song>(content: page0, totalPages: 2, page: 0);
              }
              return PageResult<Song>(content: page1, totalPages: 2, page: 1);
            },
            onTap: (_, _) async {},
            onLongPress: (_, _) {},
            isSelected: (_) => false,
            reloadToken: 0,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Track 0'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(calls, containsAllInOrder([0, 1]));

      await tester.dragUntilVisible(
        find.text('Track next'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track next'), findsOneWidget);
    });

    testWidgets('reload token resets and refetches first page', (tester) async {
      var token = 0;
      var generation = 0;

      Widget build() {
        return StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    generation++;
                    token++;
                    setState(() {});
                  },
                  child: const Text('reload'),
                ),
                Expanded(
                  child: PaginatedComponent(
                    type: TileType.list,
                    fetchPage: (_, _) async {
                      return PageResult<Song>(
                        content: [_song('g-$generation', 'Gen $generation')],
                        totalPages: 1,
                        page: 0,
                      );
                    },
                    onTap: (_, _) async {},
                    onLongPress: (_, _) {},
                    isSelected: (_) => false,
                    reloadToken: token,
                  ),
                ),
              ],
            );
          },
        );
      }

      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: build(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gen 0'), findsOneWidget);

      await tester.tap(find.text('reload'));
      await tester.pumpAndSettle();

      expect(find.text('Gen 1'), findsOneWidget);
      expect(find.text('Gen 0'), findsNothing);
    });

    testWidgets('grid tile dropdown selection maps index from actions[2+]', (
      tester,
    ) async {
      final selected = <int>[];
      final item = _song('grid-song', 'Grid Song');

      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: CustomScrollView(
            slivers: [
              CustomTileComponent(
                tileType: TileType.grid,
                items: [item],
                actions: [
                  (_) => const Icon(Icons.play_arrow),
                  (_) => const Icon(Icons.queue_music),
                  (_) => const Text('Add to queue'),
                ],
                onDropdownSelected: (_, idx) {
                  selected.add(idx);
                },
                onTap: (_) {},
                onLongPress: (_) {},
                isSelected: (_) => false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(FluentIcons.moreVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to queue').first);
      await tester.pumpAndSettle();

      expect(selected, [0]);
    });

    testWidgets('tile renders enriched entity returned by enrichEntity', (
      tester,
    ) async {
      final placeholder = Song('hydrated-song');
      final enriched = _song('hydrated-song', 'Hydrated Track');
      BaseEntity? tapped;

      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: CustomScrollView(
            slivers: [
              CustomTileComponent(
                tileType: TileType.list,
                items: [placeholder],
                enrichEntity: (_) async => enriched,
                onTap: (entity) {
                  tapped = entity;
                },
                onLongPress: (_) {},
                isSelected: (_) => false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrated Track'), findsOneWidget);
      expect(find.text('Unknown Song'), findsNothing);

      await tester.tap(find.text('Hydrated Track'));
      await tester.pumpAndSettle();

      expect(identical(tapped, enriched), isTrue);
    });

    testWidgets('shows a next-page error and retries that page', (
      tester,
    ) async {
      final page0 = List.generate(20, (i) => _song('base-$i', 'Base $i'));
      var pageOneCalls = 0;

      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: PaginatedComponent(
            type: TileType.list,
            itemExtent: 56,
            fetchPage: (page, _) async {
              if (page == 0) {
                return PageResult<Song>(content: page0, totalPages: 2, page: 0);
              }
              pageOneCalls++;
              if (pageOneCalls == 1) throw Exception('temporary failure');
              return PageResult<Song>(
                content: [_song('recovered', 'Recovered')],
                totalPages: 2,
                page: 1,
              );
            },
            onTap: (_, _) async {},
            onLongPress: (_, _) {},
            isSelected: (_) => false,
            reloadToken: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      final retry = find.text(
        'Failed to load more. Tap to retry.',
        skipOffstage: false,
      );
      expect(retry, findsOneWidget);

      final retryButton = tester.widget<TextButton>(
        find.byType(TextButton, skipOffstage: false),
      );
      retryButton.onPressed!();
      await tester.pumpAndSettle();
      expect(pageOneCalls, 2);
      expect(find.text('Failed to load more. Tap to retry.'), findsNothing);
    });

    testWidgets('honors initial delay and refresh callback', (tester) async {
      var fetches = 0;
      var refreshes = 0;
      await tester.pumpWidget(
        _withProviders(
          audioProvider: audioProvider,
          coverService: coverService,
          child: PaginatedComponent(
            type: TileType.list,
            initialLoadDelay: const Duration(milliseconds: 10),
            fetchPage: (page, _) async {
              fetches++;
              return PageResult<Song>(
                content: [_song('refresh-$fetches', 'Refresh $fetches')],
                totalPages: 1,
                page: page,
              );
            },
            onRefresh: () async {
              refreshes++;
            },
            onTap: (_, _) async {},
            onLongPress: (_, _) {},
            isSelected: (_) => false,
            reloadToken: 0,
          ),
        ),
      );

      expect(fetches, 0);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(fetches, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(fetches, 2);
    });
  });
}
