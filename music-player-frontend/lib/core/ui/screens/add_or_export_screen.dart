import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractAddOrExportScreen extends StatefulWidget {
  final List<Song> songs;
  final bool export;

  const AbstractAddOrExportScreen({
    super.key,
    this.songs = const [],
    this.export = false,
  });
}

abstract class AbstractAddOrExportScreenState<
  T extends AbstractAddOrExportScreen
>
    extends State<T> {
  late ValueNotifier<List<Playlist>> selected;

  @override
  void initState() {
    super.initState();
    selected = ValueNotifier<List<Playlist>>([]);
  }

  @override
  void dispose() {
    selected.dispose();
    super.dispose();
  }

  void handleDone() {
    if (selected.value.isEmpty) {
      showToast("Please select at least one playlist");
      return;
    }

    if (widget.export) {
      _exportPlaylists();
      Navigator.pop(context);
      return;
    }

    _addSongsToPlaylists();
    Navigator.pop(context);
  }

  void _exportPlaylists() {
    final appStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    final fileService = Provider.of<FileService>(context, listen: false);

    for (final playlist in selected.value) {
      final songPaths = playlist.songsList.map((e) => e.path).toList();
      final fileName =
          "${appStateProvider.appSettings.mainSongPlace}/${playlist.name}.m3u";
      fileService.exportPlaylist(fileName, songPaths);
    }
  }

  void _addSongsToPlaylists() {
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );

    for (final playlist in selected.value) {
      playlistProvider.addSongsToPlaylist(playlist, widget.songs);
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
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  Widget buildHeader(BuildContext context) {
    return const SizedBox.shrink();
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.zero;
  }

  Widget buildBody(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildHeader(context),
        Expanded(
          child: FutureBuilder(
            future: Future(
              () =>
                  widget.export
                      ? playlistProvider.getAllPlaylists()
                      : playlistProvider.getNormalPlaylists(),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint(snapshot.error.toString());
                debugPrintStack();
                return Center(
                  child: Text(
                    "Error loading playlists",
                    style:
                        MusicPlayerTheme.getTheme(
                          context,
                          context.read<Scaler>(),
                        ).textTheme.bodyMedium,
                  ),
                );
              }
              List<Playlist> items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    "No playlists found",
                    style:
                        MusicPlayerTheme.getTheme(
                          context,
                          context.read<Scaler>(),
                        ).textTheme.bodyMedium,
                  ),
                );
              }
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: width * 0.01,
                      right: width * 0.01,
                    ),
                    sliver: ValueListenableBuilder(
                      valueListenable: selected,
                      builder: (context, value, child) {
                        return CustomGridComponent(
                          items: items,
                          isSelected: (entity) {
                            return selected.value.contains(entity as Playlist);
                          },
                          onTap: (entity) {
                            debugPrint("Tapped on ${entity.name}");
                            if (selected.value.contains(entity as Playlist)) {
                              selected.value = List<Playlist>.from(
                                selected.value,
                              )..remove(entity);
                            } else {
                              selected.value = List<Playlist>.from(
                                selected.value,
                              )..add(entity);
                            }
                          },
                          onLongPress: (entity) {
                            debugPrint("Long pressed on ${entity.name}");
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
