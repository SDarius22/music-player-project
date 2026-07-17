import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class _Playlists extends ChangeNotifier implements PlaylistProvider {
  _Playlists(this.result, {this.error});

  final ({List<Playlist> content, int page, int totalPages}) result;
  final Object? error;
  int calls = 0;

  @override
  Future<({List<Playlist> content, int page, int totalPages})>
  getNormalPlaylists(int page, int size) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Widget _host(PlaylistProvider provider, AddOrExportScreen child) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaylistProvider>.value(value: provider),
        Provider<CoverService>.value(value: _Cover()),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    );

void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('loads, displays, and selects playlists', (tester) async {
    _useWideSurface(tester);
    final playlist = Playlist('Road Trip');
    final provider = _Playlists((content: [playlist], page: 0, totalPages: 1));
    await tester.pumpWidget(_host(provider, const AddOrExportScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Choose one or more'), findsOneWidget);
    expect(find.text('Road Trip'), findsWidgets);
    expect(provider.calls, 1);
    await tester.tap(find.text('Road Trip').first, warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state', (tester) async {
    _useWideSurface(tester);
    final provider = _Playlists((content: [], page: 0, totalPages: 0));
    await tester.pumpWidget(_host(provider, const AddOrExportScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text('No playlists found'), findsOneWidget);
  });

  testWidgets('shows an error and retries loading', (tester) async {
    _useWideSurface(tester);
    final provider = _Playlists((
      content: [],
      page: 0,
      totalPages: 1,
    ), error: Exception('offline'));
    await tester.pumpWidget(_host(provider, const AddOrExportScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Error loading playlists'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(provider.calls, 2);
  });

  testWidgets('route distinguishes add and export destinations', (
    tester,
  ) async {
    final add = AddOrExportScreen.route(songs: [Song('song')]);
    final export = AddOrExportScreen.route(export: true);
    expect(add.settings.name, '/add');
    expect(export.settings.name, '/export');
  });
}
