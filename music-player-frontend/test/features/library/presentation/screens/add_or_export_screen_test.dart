import 'dart:typed_data';
import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/dtos/playlists/playlist_page_dto.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/playlist_rest_client.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/features/library/application/playlist_file_gateway.dart';
import 'package:music_player_frontend/features/library/application/playlist_transfer_service.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';
import 'package:music_player_frontend/features/library/presentation/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/features/library/presentation/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/features/player/presentation/providers/audio_provider.dart';
import 'package:music_player_frontend/shared/presentation/tiling/grid_tile.dart';
import 'package:provider/provider.dart';

class _Playlists extends ChangeNotifier implements PlaylistProvider {
  _Playlists(this.result, {this.error});

  final ({List<Playlist> content, int page, int totalPages}) result;
  final Object? error;
  int calls = 0;
  final List<({Playlist playlist, List<Song> songs})> additions = [];

  @override
  Future<({List<Playlist> content, int page, int totalPages})>
  getNormalPlaylists(int page, int size) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> addSongsToPlaylist(Playlist playlist, List<Song> songs) async {
    additions.add((playlist: playlist, songs: songs));
  }

  @override
  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  }) async => PageResult<Song>(
    content: result.content.expand((playlist) => playlist.getSongs()).toList(),
    totalPages: 1,
    page: page,
  );

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

class _OfflinePlaylistRestClient extends PlaylistRestClient {
  _OfflinePlaylistRestClient()
    : super(
        baseUrl: 'http://localhost',
        authService: AuthService(baseUrl: 'http://localhost'),
      );

  @override
  Future<PlaylistPageDto> getPlaylistsPage({
    String? query,
    bool? filterIndestructible,
    bool? includeQueue,
    int page = 0,
    int size = 50,
  }) async => PlaylistPageDto(
    content: const [],
    page: page,
    size: size,
    totalPages: 0,
    totalElements: 0,
  );
}

class _UnusedSongService extends Fake implements SongService {}

class _Audio extends Fake implements AudioProvider {
  final List<List<Song>> queueAdditions = [];

  @override
  Future<void> addLastToQueue(List<Song> songs) async {
    queueAdditions.add(songs);
  }
}

class _Gateway implements PlaylistFileGateway {
  final List<({String fileName, Uint8List bytes})> exports = [];

  @override
  Future<PlaylistFileData?> pickPlaylist() async => null;

  @override
  Future<bool> savePlaylist({
    required String fileName,
    required Uint8List bytes,
  }) async {
    exports.add((fileName: fileName, bytes: bytes));
    return true;
  }
}

Widget _host(
  PlaylistProvider provider,
  AddOrExportScreen child, {
  AudioProvider? audio,
  PlaylistFileGateway? gateway,
  PlaylistTransferService? transfer,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<PlaylistProvider>.value(value: provider),
    Provider<CoverService>.value(value: _Cover()),
    if (audio != null) Provider<AudioProvider>.value(value: audio),
    if (gateway != null) Provider<PlaylistFileGateway>.value(value: gateway),
    if (transfer != null)
      Provider<PlaylistTransferService>.value(value: transfer),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    builder: BotToastInit(),
    navigatorObservers: [BotToastNavigatorObserver()],
    home: child,
  ),
);

void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _playlistTile(String name) => find.byWidgetPredicate(
  (widget) => widget is CustomGridTile && widget.entity?.getName() == name,
);

void main() {
  Provider.debugCheckInvalidValueType = null;

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

  testWidgets('web repository-backed add screen includes Queue', (
    tester,
  ) async {
    _useWideSurface(tester);
    final repository = InMemoryPlaylistRepository();
    repository.savePlaylist(Playlist('Queue')..indestructible = true);
    repository.savePlaylist(Playlist('Road Trip'));
    final provider = PlaylistProvider(
      PlaylistService(
        repository,
        _OfflinePlaylistRestClient(),
        InMemorySongRepository(),
        _UnusedSongService(),
      ),
    );

    await tester.pumpWidget(_host(provider, const AddOrExportScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Queue'), findsWidgets);
    expect(find.text('Road Trip'), findsWidgets);
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

  testWidgets('Done sends Queue and normal playlist through their own paths', (
    tester,
  ) async {
    _useWideSurface(tester);
    final queue = Playlist('Queue')..indestructible = true;
    final normal = Playlist('Favorites');
    final songs = [Song('one'), Song('two')];
    final provider = _Playlists((
      content: [queue, normal],
      page: 0,
      totalPages: 1,
    ));
    final audio = _Audio();

    await tester.pumpWidget(
      _host(provider, AddOrExportScreen(songs: songs), audio: audio),
    );
    await tester.pumpAndSettle();

    await tester.tap(_playlistTile('Queue'));
    await tester.pumpAndSettle();
    await tester.tap(_playlistTile('Favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(audio.queueAdditions, [songs]);
    expect(provider.additions, [(playlist: normal, songs: songs)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a selected playlist again removes it', (tester) async {
    _useWideSurface(tester);
    final playlist = Playlist('Toggle me');
    final provider = _Playlists((content: [playlist], page: 0, totalPages: 1));

    await tester.pumpWidget(_host(provider, const AddOrExportScreen()));
    await tester.pumpAndSettle();
    await tester.tap(_playlistTile('Toggle me'));
    await tester.pumpAndSettle();
    await tester.tap(_playlistTile('Toggle me'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('mass export uses the selected portable M3U8 format', (
    tester,
  ) async {
    _useWideSurface(tester);
    final songs = [Song('first'), Song('second')];
    final playlist = Playlist('Road Trip', songs: songs);
    final provider = _Playlists((content: [playlist], page: 0, totalPages: 1));
    final gateway = _Gateway();

    await tester.pumpWidget(
      _host(
        provider,
        const AddOrExportScreen(export: true),
        gateway: gateway,
        transfer: PlaylistTransferService(_UnusedSongService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Road Trip').first, warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portable M3U8'));
    await tester.pumpAndSettle();

    expect(gateway.exports, hasLength(1));
    expect(gateway.exports.single.fileName, 'Road Trip.m3u8');
    final exported = utf8.decode(gateway.exports.single.bytes);
    expect(exported, contains('#PLAYLIST:Road Trip'));
    expect(exported, contains('#MPM-HASH:first'));
    expect(exported, contains('music-player://song/second'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling export format keeps mass selection open', (
    tester,
  ) async {
    _useWideSurface(tester);
    final playlist = Playlist('Stay Open', songs: [Song('song')]);
    final provider = _Playlists((content: [playlist], page: 0, totalPages: 1));

    await tester.pumpWidget(
      _host(provider, const AddOrExportScreen(export: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(_playlistTile('Stay Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('to export'), findsOneWidget);
  });

  testWidgets('route builds the requested add screen', (tester) async {
    _useWideSurface(tester);
    final provider = _Playlists((content: [], page: 0, totalPages: 1));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaylistProvider>.value(value: provider),
          Provider<CoverService>.value(value: _Cover()),
        ],
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        AddOrExportScreen.route(songs: [Song('route-song')]),
                      ),
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('add to'), findsOneWidget);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
