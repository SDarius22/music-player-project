import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/paginated_component.dart';
import 'package:music_player_frontend/core/ui/components/tiling/tile_type.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

enum _PlaylistAction { add, export, editToggle, delete }

class PlaylistScreen extends EntityScreen<PlaylistProvider> {
  static Route<void> route({required Playlist playlist}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => PlaylistScreen(
        entity: playlist,
        provider: context.read<PlaylistProvider>(),
      ),
      settings: RouteSettings(name: "/playlist/${playlist.id}"),
    );
  }

  PlaylistScreen({super.key, required super.entity, required super.provider});

  final ValueNotifier<bool> editMode = ValueNotifier<bool>(false);
  final ValueNotifier<bool> orderChanged = ValueNotifier<bool>(false);

  @override
  Future<BaseEntity> loadEntityData(BuildContext context) async {
    final playlist = entity as Playlist;
    try {
      final fetchedPlaylist = await context
          .read<PlaylistProvider>()
          .fetchEntity(playlist);
      debugPrint("Fetched playlist $fetchedPlaylist");
      return fetchedPlaylist!;
    } catch (e) {
      debugPrint("Error fetching playlist details: $e");
      return playlist;
    }
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final playlist = entity as Playlist;
    final List<Song> songs = playlist.getSongs();
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () {
                debugPrint("Back");
                Navigator.pop(context);
              },
              icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            Text(
              entity.getName(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const Spacer(),
            IconButton(
              tooltip: "Add",
              padding: EdgeInsets.all(height * 0.005),
              onPressed: () {
                debugPrint("Add ${playlist.name}");
                var abstractAppStateProvider =
                    Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    );
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
              onPressed: () async {
                if (songs.isEmpty) return;
                final audioProvider = context.read<AudioProvider>();
                await audioProvider.setShuffleAndWait(true);
                final shuffled = List<Song>.from(songs)..shuffle();
                await audioProvider.setQueueAndPlay(songs, shuffled.first);
              },
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
                              var playlistProvider =
                                  Provider.of<PlaylistProvider>(
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
                      icon: Icon(
                        FluentIcons.check,
                        size: 20,
                        color: Colors.white,
                      ),
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
                              Icon(
                                FluentIcons.trash,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Delete",
                                style: TextStyle(color: Colors.red),
                              ),
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
        ),
      ),
    );
  }

  @override
  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final playlist = entity as Playlist;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    var margin = EdgeInsets.symmetric(
      vertical: height * 0.01,
      horizontal: width * 0.02,
    );
    var borderRadius = BorderRadius.circular(height * 0.015);

    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
      blur: 45.0,
      borderWidth: 0.0,
      elevation: 3.0,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      child: PaginatedComponent(
        type: TileType.list,
        itemExtent: height * 0.1,
        fetchPage:
            (page, size) =>
                provider.getPlaylistSongsPage(playlist, page: page, size: size),
        onTap: (BaseEntity selected, List<dynamic> items) async {
          final audioProvider = context.read<AudioProvider>();
          final queue = items.whereType<Song>().toList(growable: false);
          if (queue.isEmpty) {
            return;
          }
          await audioProvider.setQueueAndPlay(queue, selected as Song);
        },
        onLongPress: (BaseEntity entity, List<dynamic> items) {},
        isSelected: (BaseEntity p1) => false,
        reloadToken: playlist.getHash(),
      ),
    );
  }
}
