import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/grid_component.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/album_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/track_screen.dart';
import 'package:provider/provider.dart';

class Tracks extends StatefulWidget {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/songs'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Tracks();
      },
    );
  }

  const Tracks({super.key});

  @override
  State<Tracks> createState() => _TracksState();
}

class _TracksState extends State<Tracks> {
  ValueNotifier<List<Song>> selected = ValueNotifier<List<Song>>([]);

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
        borderColor: Colors.transparent,
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.height * 0.015,
        ),
        blur: 45.0,
        borderWidth: 0.0,
        elevation: 3.0,
        shadowColor: Colors.black.withOpacity(0.20),
        padding: EdgeInsets.only(bottom: height * 0.01),
        child: Consumer<SongProvider>(
          builder: (context, songProvider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: height * 0.065,
                  width: width,
                  padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                  child: LinuxSearchHeader(
                    title: 'Tracks',
                    provider: songProvider,
                  ),
                ),
                Expanded(
                  child: FutureBuilder(
                    future: songProvider.songsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        debugPrint(snapshot.error.toString());
                        debugPrintStack();
                        return const Center(child: Text("Error loading songs"));
                      }
                      debugPrint("Songs loaded: ${snapshot.data?.length ?? 0}");
                      return RepaintBoundary(
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.only(
                                left: width * 0.01,
                                right: width * 0.01,
                                bottom: height * 0.1,
                              ),
                              sliver: ValueListenableBuilder(
                                valueListenable: selected,
                                builder: (context, value, child) {
                                  return GridComponent(
                                    items: snapshot.data ?? [],
                                    isSelected: (entity) {
                                      Song song = entity as Song;
                                      return selected.value.contains(song);
                                    },
                                    onTap: (entity) async {
                                      debugPrint("tapped ${entity.name}");
                                      Song song = entity as Song;

                                      if (selected.value.isNotEmpty) {
                                        if (selected.value.contains(song)) {
                                          selected.value = List<Song>.from(
                                            selected.value,
                                          )..remove(song);
                                        } else {
                                          selected.value = List<Song>.from(
                                            selected.value,
                                          )..add(song);
                                        }
                                        return;
                                      }

                                      var audioProvider =
                                          Provider.of<AbstractAudioProvider>(
                                            context,
                                            listen: false,
                                          );
                                      try {
                                        if (audioProvider.currentSong.path !=
                                            song.path) {
                                          List<Song> songs =
                                              snapshot.data as List<Song>;
                                          audioProvider.setQueue(songs);
                                          await audioProvider.setCurrentSong(
                                            song,
                                          );
                                          await audioProvider.play();
                                        } else {
                                          if (audioProvider
                                                  .playingNotifier
                                                  .value ==
                                              true) {
                                            debugPrint("Pausing song");
                                            await audioProvider.pause();
                                          } else {
                                            debugPrint("Playing song");
                                            await audioProvider.play();
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint(e.toString());
                                        List<Song> songs =
                                            snapshot.data as List<Song>;
                                        audioProvider.setQueue(songs);
                                        await audioProvider.setCurrentSong(
                                          song,
                                        );
                                        await audioProvider.play();
                                      }
                                    },
                                    onLongPress: (entity) {
                                      debugPrint("long pressed ${entity.name}");
                                      Song song = entity as Song;
                                      if (selected.value.contains(song)) {
                                        selected.value = List<Song>.from(
                                          selected.value,
                                        )..remove(song);
                                      } else {
                                        selected.value = List<Song>.from(
                                          selected.value,
                                        )..add(song);
                                      }
                                    },
                                    buildLeftAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return const SizedBox.shrink();
                                      }
                                      return IconButton(
                                        tooltip: "Go to Album",
                                        onPressed: () {
                                          Song song = entity as Song;
                                          Navigator.push(
                                            context,
                                            AlbumScreen.route(
                                              album: song.album.target as Album,
                                            ),
                                          );
                                        },
                                        padding: const EdgeInsets.all(0),
                                        icon: Icon(
                                          FluentIcons.album,
                                          color: Colors.white,
                                          size: height * 0.03,
                                        ),
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
                                      return Consumer<AbstractAudioProvider>(
                                        builder: (_, audioProvider, __) {
                                          Song song = entity as Song;
                                          return ValueListenableBuilder(
                                            valueListenable:
                                                audioProvider.playingNotifier,
                                            builder: (
                                              context,
                                              isPlaying,
                                              child,
                                            ) {
                                              return Icon(
                                                audioProvider
                                                                .currentSong
                                                                .path ==
                                                            song.path &&
                                                        audioProvider
                                                                .playingNotifier
                                                                .value ==
                                                            true
                                                    ? FluentIcons.pause
                                                    : FluentIcons.play,
                                                color: Colors.white,
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                    buildRightAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return const SizedBox.shrink();
                                      }
                                      return PopupMenuButton<String>(
                                        icon: Icon(
                                          FluentIcons.moreVertical,
                                          color: Colors.white,
                                          size: height * 0.03,
                                        ),
                                        onSelected: (String value) {
                                          switch (value) {
                                            case 'add':
                                              var appState = Provider.of<
                                                AbstractAppStateProvider
                                              >(context, listen: false);
                                              appState.navigatorKey.currentState
                                                  ?.push(
                                                    AddOrExportScreen.route(
                                                      songs: [entity as Song],
                                                    ),
                                                  );
                                              break;
                                            case 'playNext':
                                              var audioProvider = Provider.of<
                                                AbstractAudioProvider
                                              >(context, listen: false);
                                              audioProvider.addNextToQueue(
                                                (entity as Song),
                                              );
                                              break;
                                            case 'select':
                                              debugPrint(
                                                "Select ${entity.name}",
                                              );
                                              Song song = entity as Song;
                                              if (selected.value.contains(
                                                entity,
                                              )) {
                                                selected
                                                    .value = List<Song>.from(
                                                  selected.value,
                                                )..remove(song);
                                              } else {
                                                selected
                                                    .value = List<Song>.from(
                                                  selected.value,
                                                )..add(song);
                                              }
                                              break;
                                            case 'details':
                                              debugPrint(
                                                "Details ${entity.name}",
                                              );
                                              var appState = Provider.of<
                                                AbstractAppStateProvider
                                              >(context, listen: false);
                                              appState.navigatorKey.currentState
                                                  ?.push(
                                                    TrackScreen.route(
                                                      song: entity as Song,
                                                    ),
                                                  );
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
                                            const PopupMenuItem<String>(
                                              value: 'details',
                                              child: Text("Track Details"),
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
                        ),
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
                      label: Text("Add", textAlign: TextAlign.center),
                      onPressed: () {
                        debugPrint("Add button pressed");
                        if (selected.value.isEmpty) {
                          return;
                        }
                        var appState = Provider.of<AbstractAppStateProvider>(
                          context,
                          listen: false,
                        );
                        appState.navigatorKey.currentState
                            ?.push(
                              AddOrExportScreen.route(songs: selected.value),
                            )
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
