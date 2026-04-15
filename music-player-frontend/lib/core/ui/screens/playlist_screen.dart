import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

enum _PlaylistAction { add, export, editToggle, delete }

class PlaylistScreen extends EntityScreen {
  static Route<void> route({required Playlist playlist}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          PlaylistScreen(entity: playlist),
      settings: RouteSettings(name: "/playlist/${playlist.id}"),
    );
  }

  PlaylistScreen({super.key, required super.entity});

  final ValueNotifier<bool> editMode = ValueNotifier<bool>(false);
  final ValueNotifier<bool> orderChanged = ValueNotifier<bool>(false);

  @override
  Future<BaseEntity> loadEntityData(BuildContext context) async {
    final playlist = entity as Playlist;
    try {
      final fetchedPlaylist = await context
          .read<PlaylistProvider>()
          .fetchPlaylistDetails(playlist);
      debugPrint("Fetched playlist $fetchedPlaylist");
      return fetchedPlaylist;
    } catch (e) {
      debugPrint("Error fetching playlist details: $e");
      return playlist;
    }
  }

  @override
  Widget buildBody(BuildContext context, BaseEntity entity) {
    final playlist = entity as Playlist;
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    final List<Song> songs = playlist.getSongs();

    Widget buildSongList(double itemExtent) {
      return ValueListenableBuilder(
        valueListenable: editMode,
        builder: (context, value, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            reverseDuration: const Duration(milliseconds: 500),
            child:
                value == false
                    ? CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            vertical: height * 0.01,
                            horizontal: width * 0.01,
                          ),
                          sliver: ListComponent(
                            items: songs,
                            itemExtent: itemExtent,
                            isSelected: (entity) => false,
                            onTap: (entity) async {
                              debugPrint("Tapped on ${entity.getName()}");
                              final audioProvider = Provider.of<AudioProvider>(
                                context,
                                listen: false,
                              );
                              await audioProvider.setQueueAndPlay(
                                songs,
                                entity as Song,
                              );
                            },
                            onLongPress: (entity) {
                              debugPrint("Long pressed on ${entity.getName()}");
                            },
                          ),
                        ),
                      ],
                    )
                    : ValueListenableBuilder(
                      valueListenable: orderChanged,
                      builder: (context, value2, child) {
                        return ReorderableListView.builder(
                          key: const ValueKey("Edit List"),
                          padding: EdgeInsets.only(right: width * 0.01),
                          itemBuilder: (context, int index) {
                            final Song song = songs[index];
                            return AnimatedContainer(
                              key: Key('$index'),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              height: itemExtent,
                              child: Container(
                                padding: EdgeInsets.only(
                                  left: width * 0.0075,
                                  right: width * 0.025,
                                  top: height * 0.0075,
                                  bottom: height * 0.0075,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    width * 0.01,
                                  ),
                                  color: const Color(0xFF0E0E0E),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        width * 0.01,
                                      ),
                                      child: ImageWidget(
                                        entity: song,
                                        hoveredChild: IconButton(
                                          onPressed: () {
                                            orderChanged.value =
                                                !orderChanged.value;
                                          },
                                          icon: Icon(
                                            FluentIcons.trash,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: width * 0.01),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.name.toString().length > 60
                                              ? "${song.name.toString().substring(0, 60)}..."
                                              : song.name.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(color: Colors.white),
                                        ),
                                        SizedBox(height: height * 0.001),
                                        Text(
                                          song.artist.toString().length > 60
                                              ? "${song.artist.toString().substring(0, 60)}..."
                                              : song.artist.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      song.durationInSeconds == 0
                                          ? "??:??"
                                          : "${song.durationInSeconds ~/ 60}:${(song.durationInSeconds % 60).toString().padLeft(2, '0')}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          itemCount: songs.length,
                          onReorder: (int oldIndex, int newIndex) {},
                        );
                      },
                    ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          final imageSize = constraints.maxWidth * 0.45;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.05,
                  vertical: height * 0.02,
                ),
                child: Column(
                  children: [
                    Hero(
                      tag: playlist.name,
                      child: ValueListenableBuilder(
                        valueListenable: editMode,
                        builder: (context, value, child) {
                          return Container(
                            height: imageSize,
                            width: imageSize,
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ImageWidget(entity: playlist),
                            ),
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: editMode,
                      builder: (context, value, child) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child:
                              value == false
                                  ? Text(
                                    playlist.name,
                                    key: const ValueKey("Playlist Name"),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  )
                                  : SizedBox(
                                    key: const ValueKey("Playlist Name Edit"),
                                    width: constraints.maxWidth * 0.7,
                                    child: TextFormField(
                                      initialValue: playlist.name,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: height * 0.008,
                                          horizontal: width * 0.03,
                                        ),
                                        hintText: "Playlist Name",
                                        hintStyle: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium!.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Colors.white),
                                      onChanged: (value) {
                                        playlist.name = value;
                                      },
                                    ),
                                  ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GlassContainer(
                  margin: EdgeInsets.only(
                    left: width * 0.05,
                    right: width * 0.05,
                    bottom: height * 0.025,
                  ),
                  color: Colors.black.withValues(alpha: 0.4),
                  borderColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  blur: 45.0,
                  borderWidth: 0.0,
                  elevation: 3.0,
                  shadowColor: Colors.black.withValues(alpha: 0.20),
                  child: buildSongList(height * 0.125),
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: playlist.name,
                      child: ValueListenableBuilder(
                        valueListenable: editMode,
                        builder: (context, value, child) {
                          return Container(
                            height: height * 0.5,
                            width: height * 0.5,
                            padding: EdgeInsets.only(bottom: height * 0.01),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(width * 0.01),
                              child: ImageWidget(entity: playlist),
                            ),
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: editMode,
                      builder: (context, value, child) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child:
                              value == false
                                  ? Text(
                                    playlist.name,
                                    key: const ValueKey("Playlist Name"),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  )
                                  : SizedBox(
                                    key: const ValueKey("Playlist Name Edit"),
                                    width: width * 0.2,
                                    child: TextFormField(
                                      initialValue: playlist.name,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.only(
                                          top: height * 0.008,
                                          bottom: height * 0.008,
                                          left: width * 0.01,
                                          right: width * 0.01,
                                        ),
                                        hintText: "Playlist Name",
                                        hintStyle: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium!.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            width * 0.005,
                                          ),
                                        ),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Colors.white),
                                      onChanged: (value) {
                                        playlist.name = value;
                                      },
                                    ),
                                  ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GlassContainer(
                margin: EdgeInsets.only(
                  top: height * 0.025,
                  bottom: height * 0.025,
                  right: width * 0.05,
                ),
                color: Colors.black.withValues(alpha: 0.4),
                borderColor: Colors.transparent,
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
                blur: 45.0,
                borderWidth: 0.0,
                elevation: 3.0,
                shadowColor: Colors.black.withValues(alpha: 0.20),
                child: buildSongList(height * 0.125),
              ),
            ),
            SizedBox(width: width * 0.025),
          ],
        );
      },
    );
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final playlist = entity as Playlist;
    final List<Song> songs = playlist.getSongs();
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return AppBar(
      leading: IconButton(
        onPressed: () {
          debugPrint("Back");
          Navigator.pop(context);
        },
        icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
      ),
      title: Text(entity.getName()),
      actionsPadding: EdgeInsets.symmetric(horizontal: height * 0.005),
      actions: [
        IconButton(
          tooltip: "Add",
          padding: EdgeInsets.all(height * 0.005),
          onPressed: () {
            debugPrint("Add ${playlist.name}");
            var abstractAppStateProvider =
                Provider.of<AbstractAppStateProvider>(context, listen: false);
            abstractAppStateProvider.innerNavigatorKey.currentState?.push(
              AddOrExportScreen.route(songs: playlist.getSongs()),
            );
          },
          icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
        ),
        IconButton(
          tooltip: "Play",
          padding: EdgeInsets.all(height * 0.005),
          onPressed: () async {
            final audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            await audioProvider.setQueueAndPlay(songs, songs.first);
          },
          icon: Icon(FluentIcons.play, color: Colors.white, size: 24),
        ),
        IconButton(
          tooltip: "Shuffle",
          onPressed: () async {},
          padding: EdgeInsets.all(height * 0.005),
          icon: Icon(FluentIcons.shuffleOn, color: Colors.white, size: 24),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: editMode,
          builder: (context, isEditing, child) {
            if (isEditing) {
              return SizedBox(
                height: height * 0.045,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    var action = _PlaylistAction.editToggle;

                    switch (action) {
                      case _PlaylistAction.add:
                        {
                          final abstractAppStateProvider =
                              Provider.of<AbstractAppStateProvider>(
                                context,
                                listen: false,
                              );

                          abstractAppStateProvider
                              .innerNavigatorKey
                              .currentState
                              ?.push(AddOrExportScreen.route(songs: songs));
                          return;
                        }
                      case _PlaylistAction.export:
                        {
                          debugPrint("Export ${playlist.name}");
                          final abstractAppStateProvider =
                              Provider.of<AbstractAppStateProvider>(
                                context,
                                listen: false,
                              );
                          abstractAppStateProvider
                              .innerNavigatorKey
                              .currentState
                              ?.push(
                                AddOrExportScreen.route(
                                  songs: songs,
                                  export: true,
                                ),
                              );
                          return;
                        }
                      case _PlaylistAction.editToggle:
                        {
                          editMode.value = !editMode.value;
                          return;
                        }
                      case _PlaylistAction.delete:
                        {
                          final bool? confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text("Delete playlist?"),
                                content: Text(
                                  "This will delete \"${playlist.name}\".\nThis action can't be undone.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(
                                          dialogContext,
                                        ).pop(false),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        () => Navigator.of(
                                          dialogContext,
                                        ).pop(true),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(FluentIcons.trash, size: 18),
                                        SizedBox(width: 8),
                                        Text("Delete"),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed != true) return;

                          debugPrint("Confirmed delete ${playlist.name}");
                          if (!context.mounted) return;
                          var playlistProvider = Provider.of<PlaylistProvider>(
                            context,
                            listen: false,
                          );
                          playlistProvider.deletePlaylist(playlist);
                          var appStateProvider =
                              Provider.of<AbstractAppStateProvider>(
                                context,
                                listen: false,
                              );
                          appStateProvider.innerNavigatorKey.currentState
                              ?.pop();
                          return;
                        }
                    }
                  },
                  icon: Icon(FluentIcons.check, size: 20, color: Colors.white),
                  label: Text(
                    "Done",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                  ),
                ),
              );
            }

            return PopupMenuButton<_PlaylistAction>(
              tooltip: "Actions",
              onSelected: (_PlaylistAction action) async {
                switch (action) {
                  case _PlaylistAction.add:
                    {
                      final abstractAppStateProvider =
                          Provider.of<AbstractAppStateProvider>(
                            context,
                            listen: false,
                          );

                      abstractAppStateProvider.innerNavigatorKey.currentState
                          ?.push(AddOrExportScreen.route(songs: songs));
                      return;
                    }
                  case _PlaylistAction.export:
                    {
                      debugPrint("Export ${playlist.name}");
                      final abstractAppStateProvider =
                          Provider.of<AbstractAppStateProvider>(
                            context,
                            listen: false,
                          );
                      abstractAppStateProvider.innerNavigatorKey.currentState
                          ?.push(
                            AddOrExportScreen.route(songs: songs, export: true),
                          );
                      return;
                    }
                  case _PlaylistAction.editToggle:
                    {
                      editMode.value = !editMode.value;
                      return;
                    }
                  case _PlaylistAction.delete:
                    {
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text("Delete playlist?"),
                            content: Text(
                              "This will delete \"${playlist.name}\".\nThis action can't be undone.",
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () =>
                                        Navigator.of(dialogContext).pop(false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed:
                                    () => Navigator.of(dialogContext).pop(true),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FluentIcons.trash, size: 18),
                                    SizedBox(width: 8),
                                    Text("Delete"),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirmed != true) return;

                      debugPrint("Confirmed delete ${playlist.name}");
                      if (!context.mounted) return;
                      var playlistProvider = Provider.of<PlaylistProvider>(
                        context,
                        listen: false,
                      );
                      playlistProvider.deletePlaylist(playlist);
                      var appStateProvider =
                          Provider.of<AbstractAppStateProvider>(
                            context,
                            listen: false,
                          );
                      appStateProvider.innerNavigatorKey.currentState?.pop();
                      return;
                    }
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<_PlaylistAction>>[];

                items.add(
                  PopupMenuItem<_PlaylistAction>(
                    value: _PlaylistAction.add,
                    child: const Row(
                      children: [
                        Icon(FluentIcons.add, size: 18),
                        SizedBox(width: 10),
                        Text("Add"),
                      ],
                    ),
                  ),
                );

                items.add(
                  PopupMenuItem<_PlaylistAction>(
                    value: _PlaylistAction.export,
                    child: const Row(
                      children: [
                        Icon(FluentIcons.export, size: 18),
                        SizedBox(width: 10),
                        Text("Export"),
                      ],
                    ),
                  ),
                );

                if (playlist.indestructible == false) {
                  items.add(const PopupMenuDivider());

                  items.add(
                    PopupMenuItem<_PlaylistAction>(
                      value: _PlaylistAction.editToggle,
                      child: const Row(
                        children: [
                          Icon(FluentIcons.editOn, size: 18),
                          SizedBox(width: 10),
                          Text("Edit"),
                        ],
                      ),
                    ),
                  );

                  items.add(
                    PopupMenuItem<_PlaylistAction>(
                      value: _PlaylistAction.delete,
                      child: const Row(
                        children: [
                          Icon(FluentIcons.trash, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Delete", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }

                return items;
              },
              child: Padding(
                padding: EdgeInsets.all(height * 0.005),
                child: Icon(
                  FluentIcons.moreVertical,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
