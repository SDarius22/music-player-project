import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_component.dart';
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
              onPressed: () {
                if (selected.value.isEmpty) {
                  BotToast.showText(
                    text: "Please select at least one playlist",
                  );
                  return;
                }
                if (widget.export) {
                  var abstractAppStateProvider =
                      Provider.of<AbstractAppStateProvider>(
                        context,
                        listen: false,
                      );
                  for (int i = 0; i < selected.value.length; i++) {
                    Playlist playlist = selected.value[i];
                    var songHashes =
                        playlist.getSongs().map((e) => e.getHash()).toList();
                    var fileName =
                        "${abstractAppStateProvider.appSettings.mainSongPlace}/${playlist.name}.m3u";
                    final fileService = Provider.of<AbstractFileService>(
                      context,
                      listen: false,
                    );
                    fileService.exportPlaylist(fileName, songHashes);
                  }
                }
                for (int i = 0; i < selected.value.length; i++) {
                  Playlist playlist = selected.value[i];
                  if (playlist.indestructible &&
                      playlist.name == 'Current Queue') {
                    var audioProvider = Provider.of<AudioProvider>(
                      context,
                      listen: false,
                    );
                    audioProvider.addLastToQueue(widget.songs);
                  } else {
                    var playlistProvider = Provider.of<PlaylistProvider>(
                      context,
                      listen: false,
                    );
                    playlistProvider.addSongsToPlaylist(playlist, widget.songs);
                  }
                }
                Navigator.pop(context);
              },
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
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    return FutureBuilder(
      future: Future(() => playlistProvider.getNormalPlaylists()),
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        List<Playlist> items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              "No playlists found",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(left: width * 0.01, right: width * 0.01),
              sliver: ValueListenableBuilder(
                valueListenable: selected,
                builder: (context, value, child) {
                  return CustomGridComponent(
                    items: items,
                    isSelected: (entity) {
                      return selected.value.contains(entity as Playlist);
                    },
                    onTap: (entity) {
                      debugPrint("Tapped on ${entity.getName()}");
                      if (selected.value.contains(entity as Playlist)) {
                        selected.value = List<Playlist>.from(selected.value)
                          ..remove(entity);
                      } else {
                        selected.value = List<Playlist>.from(selected.value)
                          ..add(entity);
                      }
                    },
                    onLongPress: (entity) {
                      debugPrint("Long pressed on ${entity.getName()}");
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
