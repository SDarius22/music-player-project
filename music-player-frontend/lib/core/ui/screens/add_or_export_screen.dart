import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/ui/components/tiling/custom_tile_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class AddOrExportScreen extends StatefulWidget {
  static Route route({List<Song> songs = const [], bool export = false}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          AddOrExportScreen(songs: songs, export: export),
      settings: RouteSettings(name: export ? "/export" : "/add"),
    );
  }

  final List<Song> songs;
  final bool export;

  const AddOrExportScreen({
    super.key,
    this.songs = const [],
    this.export = false,
  });

  @override
  State<AddOrExportScreen> createState() => _AddOrExportScreenState();
}

class _AddOrExportScreenState extends State<AddOrExportScreen> {
  static const int _pageSize = 30;

  late ValueNotifier<List<Playlist>> selected;
  final ScrollController _scrollController = ScrollController();
  final List<Playlist> _playlists = [];

  int _nextPage = 0;
  int _totalPages = 1;
  bool _isLoading = false;
  String? _loadError;

  bool get _hasMorePages => _nextPage < _totalPages;

  @override
  void initState() {
    super.initState();
    selected = ValueNotifier<List<Playlist>>([]);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPage(reset: true));
    });
  }

  @override
  void dispose() {
    selected.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMorePages || _isLoading) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      unawaited(_loadPage());
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
      if (reset) {
        _nextPage = 0;
        _totalPages = 1;
        _playlists.clear();
      }
    });

    try {
      final playlistProvider = Provider.of<PlaylistProvider>(
        context,
        listen: false,
      );
      final result = await playlistProvider.getNormalPlaylists(
        _nextPage,
        _pageSize,
      );
      final existingNames = _playlists.map((p) => p.name).toSet();
      final toAdd =
          result.content.where((p) => !existingNames.contains(p.name)).toList();

      setState(() {
        _playlists.addAll(toAdd);
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _nextPage = result.page + 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> handleDone() async {
    if (selected.value.isEmpty) {
      showToast("Please select at least one playlist");
      return;
    }

    if (widget.export) {
      _exportPlaylists();
      Navigator.pop(context);
      return;
    }

    await _addSongsToPlaylists();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _exportPlaylists() {
    final appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    final fileService = Provider.of<AbstractFileService>(
      context,
      listen: false,
    );

    for (final playlist in selected.value) {
      final songHashes = playlist.getSongs().map((e) => e.getHash()).toList();
      final fileName =
          "${appStateProvider.appSettings.mainSongPlace}/${playlist.name}.m3u";
      fileService.exportPlaylist(fileName, songHashes);
    }
  }

  Future<void> _addSongsToPlaylists() async {
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );

    for (final playlist in selected.value) {
      if (playlist.indestructible && playlist.name == 'Queue') {
        final audioProvider = Provider.of<AudioProvider>(
          context,
          listen: false,
        );
        await audioProvider.addLastToQueue(widget.songs);
        continue;
      }
      await playlistProvider.addSongsToPlaylist(playlist, widget.songs);
    }
  }

  void togglePlaylistSelection(Playlist playlist) {
    if (selected.value.contains(playlist)) {
      selected.value = List.from(selected.value)..remove(playlist);
    } else {
      selected.value = List.from(selected.value)..add(playlist);
    }
  }

  void showToast(String message, {int durationSeconds = 2}) {
    BotToast.showText(
      text: message,
      duration: Duration(seconds: durationSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(padding: buildPadding(context), child: buildBody(context)),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                debugPrint("Back");
                Navigator.pop(context);
              },
              icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            SizedBox(width: width * 0.01),
            Text(
              "Choose one or more playlists to ${widget.export ? 'export' : 'add to'}",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async => handleDone(),
              child: Text(
                "Done",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.zero;
  }

  Widget buildBody(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_isLoading && _playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Error loading playlists",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => unawaited(_loadPage(reset: true)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_playlists.isEmpty) {
      return Center(
        child: Text(
          "No playlists found",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(left: width * 0.01, right: width * 0.01),
          sliver: ValueListenableBuilder(
            valueListenable: selected,
            builder: (context, value, child) {
              return CustomTileComponent(
                tileType: TileType.grid,
                items: _playlists,
                isSelected: (entity) {
                  return selected.value.contains(entity as Playlist);
                },
                onTap: (entity) {
                  debugPrint("Tapped on ${entity.getName()}");
                  togglePlaylistSelection(entity as Playlist);
                },
                onLongPress: (entity) {
                  debugPrint("Long pressed on ${entity.getName()}");
                },
              );
            },
          ),
        ),
        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (_loadError != null && !_isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: TextButton(
                  onPressed: () => unawaited(_loadPage()),
                  child: const Text(
                    'Failed to load more playlists. Tap to retry.',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
