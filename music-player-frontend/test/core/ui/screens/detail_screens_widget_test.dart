import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/ui/screens/album_screen.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/track_screen.dart';
import 'package:provider/provider.dart';

class _SongProvider extends Fake implements SongProvider {}

class _AlbumProvider extends Fake implements AlbumProvider {}

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

Widget _host(Widget Function(BuildContext) builder) =>
    Provider<CoverService>.value(
      value: _Cover(),
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Builder(builder: builder)),
      ),
    );

void main() {
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
}
