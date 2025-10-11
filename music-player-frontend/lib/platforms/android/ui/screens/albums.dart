import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/album_screen.dart';
import 'package:provider/provider.dart';

class Albums extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/albums'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Albums();
      },
    );
  }

  const Albums({super.key});

  @override
  State<Albums> createState() => _AlbumsState();
}

class _AlbumsState extends State<Albums> {
  ValueNotifier<List<Album>> selected = ValueNotifier<List<Album>>([]);

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassContainer(
        height: height,
        width: width,
        color: Colors.black.withValues(alpha: 0.4),
        borderGradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.60),
            Colors.indigoAccent.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.height * 0.015,
        ),
        blur: 45.0,
        borderWidth: 1.5,
        elevation: 3.0,
        shadowColor: Colors.black.withOpacity(0.20),
        padding: EdgeInsets.only(bottom: height * 0.01),
        child: Consumer<AlbumProvider>(
          builder: (context, albumProvider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: height * 0.065,
                  width: width,
                  padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                  child: LinuxSearchHeader(
                    title: 'Albums',
                    provider: albumProvider,
                  ),
                ),
                Expanded(
                  child: FutureBuilder(
                    future: albumProvider.albumsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        debugPrint(snapshot.error.toString());
                        debugPrintStack();
                        return Center(
                          child: Text(
                            "Error loading albums",
                            style: MusicPlayerTheme.getTheme(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                          ),
                        );
                      }
                      debugPrint(
                        "Albums loaded: ${snapshot.data?.length ?? 0}",
                      );
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
                                return GridComponent(
                                  items: snapshot.data ?? [],
                                  isSelected: (entity) {
                                    return selected.value.contains(entity);
                                  },
                                  onTap: (entity) async {
                                    if (entity is Album) {
                                      if (selected.value.isNotEmpty) {
                                        if (selected.value.contains(entity)) {
                                          selected.value = List<Album>.from(
                                            selected.value,
                                          )..remove(entity);
                                        } else {
                                          selected.value = List<Album>.from(
                                            selected.value,
                                          )..add(entity);
                                        }
                                        return;
                                      }
                                      var abstractAppStateProvider =
                                          Provider.of<AbstractAppStateProvider>(
                                            context,
                                            listen: false,
                                          );
                                      abstractAppStateProvider
                                          .navigatorKey
                                          .currentState!
                                          .push(
                                            AlbumScreen.route(album: entity),
                                          );
                                    } else {
                                      debugPrint("Entity is not an Album");
                                    }
                                  },
                                  onLongPress: (entity) {
                                    debugPrint("long pressed ${entity.name}");
                                    if (entity is Album) {
                                      if (selected.value.contains(entity)) {
                                        selected.value = List<Album>.from(
                                          selected.value,
                                        )..remove(entity);
                                      } else {
                                        selected.value = List<Album>.from(
                                          selected.value,
                                        )..add(entity);
                                      }
                                    }
                                  },
                                  buildLeftAction: (entity) {
                                    if (selected.value.contains(entity)) {
                                      return SizedBox.shrink();
                                    }
                                    return IconButton(
                                      icon: Icon(
                                        FluentIcons.play,
                                        color: Colors.white,
                                        size: height * 0.025,
                                      ),
                                      onPressed: () async {
                                        debugPrint(
                                          "Playing album ${entity.name}",
                                        );
                                        if (entity is! Album) {
                                          debugPrint("Entity is not an Album");
                                          return;
                                        }
                                        Album album = entity;
                                        album.songs.sort(
                                          (a, b) => a.trackNumber.compareTo(
                                            b.trackNumber,
                                          ),
                                        );
                                        var audioProvider =
                                            Provider.of<AudioProvider>(
                                              context,
                                              listen: false,
                                            );
                                        audioProvider.setQueue(album.songs);
                                        await audioProvider.setCurrentSong(
                                          album.songs.first,
                                        );
                                      },
                                    );
                                  },
                                  buildMainAction: (entity) {
                                    if (selected.value.contains(entity)) {
                                      return Icon(
                                        FluentIcons.checkCircleOn,
                                        color: Colors.white,
                                      );
                                    }
                                    if (selected.value.isNotEmpty) {
                                      return Icon(
                                        FluentIcons.checkCircleOff,
                                        color: Colors.white,
                                      );
                                    }
                                    return Icon(
                                      FluentIcons.open,
                                      color: Colors.white,
                                      size: height * 0.03,
                                    );
                                  },
                                  buildRightAction: (entity) {
                                    if (selected.value.contains(entity)) {
                                      return SizedBox.shrink();
                                    }
                                    return PopupMenuButton<String>(
                                      icon: Icon(
                                        FluentIcons.moreVertical,
                                        color: Colors.white,
                                        size: height * 0.03,
                                      ),
                                      onSelected: (String value) async {
                                        switch (value) {
                                          case 'add':
                                            Album album = entity as Album;
                                            album.songs.sort(
                                              (a, b) => a.trackNumber.compareTo(
                                                b.trackNumber,
                                              ),
                                            );
                                            var abstractAppStateProvider =
                                                Provider.of<
                                                  AbstractAppStateProvider
                                                >(context, listen: false);
                                            abstractAppStateProvider
                                                .navigatorKey
                                                .currentState!
                                                .push(
                                                  AddOrExportScreen.route(
                                                    songs: album.songs,
                                                  ),
                                                );
                                            break;
                                          case 'playNext':
                                            Album album = entity as Album;
                                            album.songs.sort(
                                              (a, b) => b.trackNumber.compareTo(
                                                a.trackNumber,
                                              ),
                                            );
                                            var audioProvider =
                                                Provider.of<AudioProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            audioProvider
                                                .addMultipleNextToQueue(
                                                  album.songs,
                                                );
                                            break;
                                          case 'select':
                                            Album album = entity as Album;
                                            if (selected.value.contains(
                                              album,
                                            )) {
                                              selected.value = List<Album>.from(
                                                selected.value,
                                              )..remove(album);
                                            } else {
                                              selected.value = List<Album>.from(
                                                selected.value,
                                              )..add(album);
                                            }
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) {
                                        return [
                                          const PopupMenuItem<String>(
                                            value: 'add',
                                            child: Text("Add to Playlist"),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'playNext',
                                            child: Text("Play Next"),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'select',
                                            child: Text("Select"),
                                          ),
                                        ];
                                      },
                                    );
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
          },
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: selected,
        builder: (context, value, child) {
          return Visibility(
            visible: value.isNotEmpty,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.1,
              height: MediaQuery.of(context).size.height * 0.05,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.1,
              ),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
              ),
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        FluentIcons.add,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.height * 0.02,
                      ),
                      label: Text(
                        "Add",
                        style:
                            MusicPlayerTheme.getTheme(
                              context,
                            ).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () async {
                        debugPrint("Add button pressed");
                        if (selected.value.isEmpty) {
                          return;
                        }
                        var appState = Provider.of<AbstractAppStateProvider>(
                          context,
                          listen: false,
                        );
                        var songs =
                            selected.value.expand((album) {
                              album.songs.sort(
                                (a, b) =>
                                    a.trackNumber.compareTo(b.trackNumber),
                              );
                              return album.songs;
                            }).toList();
                        appState.navigatorKey.currentState
                            ?.push(AddOrExportScreen.route(songs: songs))
                            .then((value) {
                              selected.value = [];
                            });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            bottomLeft: Radius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: MediaQuery.of(context).size.height * 0.05,
                    color: Colors.grey,
                  ),
                  IconButton(
                    onPressed: () {
                      debugPrint("Delete button pressed");
                      if (selected.value.isEmpty) {
                        return;
                      }
                      selected.value = [];
                    },
                    icon: Icon(
                      FluentIcons.trash,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.height * 0.02,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
