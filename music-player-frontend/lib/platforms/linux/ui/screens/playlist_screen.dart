import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class PlaylistScreen extends StatefulWidget {
  static Route<void> route({required Playlist playlist}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/playlist', arguments: Playlist),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PlaylistScreen(playlist: playlist);
      },
    );
  }

  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  ValueNotifier<bool> editMode = ValueNotifier<bool>(false);
  ValueNotifier<bool> orderChanged = ValueNotifier<bool>(false);
  List<Song> songs = [];

  @override
  void initState() {
    super.initState();
    songs = widget.playlist.songsInOrder;
    debugPrint(
      "Loaded ${songs.length} songs from ${widget.playlist.playlistSongs.length} paths",
    );
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassContainer(
        width: width,
        height: height,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: height * 0.065,
              width: width,
              padding: EdgeInsets.symmetric(horizontal: width * 0.01),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      debugPrint("Back");
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      FluentIcons.back,
                      size: height * 0.02,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: "Add",
                    padding: EdgeInsets.all(height * 0.005),
                    onPressed: () {
                      var abstractAppStateProvider =
                          Provider.of<AbstractAppStateProvider>(
                            context,
                            listen: false,
                          );
                      abstractAppStateProvider.navigatorKey.currentState?.push(
                        AddOrExportScreen.route(songs: songs),
                      );
                    },
                    icon: Icon(
                      FluentIcons.add,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                  IconButton(
                    tooltip: "Play",
                    padding: EdgeInsets.all(height * 0.005),
                    onPressed: () async {
                      var audioProvider = Provider.of<AbstractAudioProvider>(
                        context,
                        listen: false,
                      );
                      audioProvider.setQueue(songs);
                      await audioProvider.setCurrentSong(songs.first);
                      audioProvider.play();
                    },
                    icon: Icon(
                      FluentIcons.play,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                  IconButton(
                    tooltip: "Shuffle",
                    onPressed: () async {},
                    padding: EdgeInsets.all(height * 0.005),
                    icon: Icon(
                      FluentIcons.shuffleOn,
                      color: Colors.white,
                      size: height * 0.025,
                    ),
                  ),
                  if (widget.playlist.indestructible == false)
                    SizedBox(
                      width: width * 0.06,
                      child: ValueListenableBuilder(
                        valueListenable: editMode,
                        builder: (context, value, child) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: width * 0.01,
                              ),
                            ),
                            onPressed: () {
                              debugPrint("Edit ${widget.playlist.name}");
                              if (editMode.value == false) {
                                editMode.value = true;
                              } else {
                                editMode.value = false;
                                // DataController.playlistBox.put(widget.playlist);
                              }
                            },
                            child: Text(
                              value ? "Done" : "Edit",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
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
                            tag: widget.playlist.name,
                            child: ValueListenableBuilder(
                              valueListenable: editMode,
                              builder: (context, value, child) {
                                return Container(
                                  height: height * 0.5,
                                  width: height * 0.5,
                                  padding: EdgeInsets.only(
                                    bottom: height * 0.01,
                                  ),
                                  //color: Colors.red,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      width * 0.01,
                                    ),
                                    child: ImageWidget(entity: widget.playlist),
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
                                          widget.playlist.name,
                                          key: const ValueKey("Playlist Name"),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: boldSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                        : SizedBox(
                                          key: const ValueKey(
                                            "Playlist Name Edit",
                                          ),
                                          width: width * 0.2,
                                          child: TextFormField(
                                            initialValue: widget.playlist.name,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.only(
                                                top: height * 0.008,
                                                bottom: height * 0.008,
                                                left: width * 0.01,
                                                right: width * 0.01,
                                              ),
                                              hintText: "Playlist Name",
                                              hintStyle: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: normalSize,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      width * 0.005,
                                                    ),
                                              ),
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: normalSize,
                                            ),
                                            onChanged: (value) {
                                              widget.playlist.name = value;
                                            },
                                          ),
                                        ),
                              );
                            },
                          ),

                          //TODO: Artists

                          // SizedBox(
                          //   height: height * 0.005,
                          // ),
                          // Text(
                          //   widget.playlist.,
                          //   maxLines: 2,
                          //   overflow: TextOverflow.ellipsis,
                          //   textAlign: TextAlign.center,
                          //   style: TextStyle(
                          //     fontSize: normalSize,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
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
                      padding: EdgeInsets.only(
                        right: width * 0.01,
                        top: height * 0.01,
                        bottom: height * 0.01,
                      ),
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
                      isFrostedGlass: true,
                      frostedOpacity: 0.15,
                      child: ValueListenableBuilder(
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
                                          padding: EdgeInsets.only(
                                            bottom: height * 0.02,
                                          ),
                                          sliver: ListComponent(
                                            items: songs,
                                            itemExtent: height * 0.125,
                                            isSelected: (entity) {
                                              return false;
                                            },
                                            onTap: (entity) async {
                                              debugPrint(
                                                "Tapped on ${entity.name}",
                                              );
                                              var audioProvider = Provider.of<
                                                AbstractAudioProvider
                                              >(context, listen: false);
                                              audioProvider.setQueue(songs);
                                              await audioProvider
                                                  .setCurrentSong(
                                                    (entity as Song),
                                                  );
                                            },
                                            onLongPress: (entity) {
                                              debugPrint(
                                                "Long pressed on ${entity.name}",
                                              );
                                              // Show context menu or options
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
                                          padding: EdgeInsets.only(
                                            right: width * 0.01,
                                          ),
                                          itemBuilder: (context, int index) {
                                            //debugPrint("Building ${widget.playlist. songs.value[widget.playlist.order[index]].title}");
                                            Song song = songs[index];
                                            return AnimatedContainer(
                                              key: Key('$index'),
                                              duration: const Duration(
                                                milliseconds: 500,
                                              ),
                                              curve: Curves.easeInOut,
                                              height: height * 0.125,
                                              child: Container(
                                                padding: EdgeInsets.only(
                                                  left: width * 0.0075,
                                                  right: width * 0.025,
                                                  top: height * 0.0075,
                                                  bottom: height * 0.0075,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        width * 0.01,
                                                      ),
                                                  color: const Color(
                                                    0xFF0E0E0E,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            width * 0.01,
                                                          ),
                                                      child: ImageWidget(
                                                        entity: song,
                                                        hoveredChild: IconButton(
                                                          onPressed: () {
                                                            // widget
                                                            //     .playlist
                                                            //     .pathsInOrder
                                                            //     .removeAt(
                                                            //       index,
                                                            //     );
                                                            orderChanged.value =
                                                                !orderChanged
                                                                    .value;
                                                          },
                                                          icon: Icon(
                                                            FluentIcons.trash,
                                                            color: Colors.white,
                                                            size: height * 0.02,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: width * 0.01,
                                                    ),
                                                    Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          song.name
                                                                      .toString()
                                                                      .length >
                                                                  60
                                                              ? "${song.name.toString().substring(0, 60)}..."
                                                              : song.name
                                                                  .toString(),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize:
                                                                normalSize,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height:
                                                              height * 0.001,
                                                        ),
                                                        Text(
                                                          song.artist
                                                                      .toString()
                                                                      .length >
                                                                  60
                                                              ? "${song.artist.toString().substring(0, 60)}..."
                                                              : song.artist
                                                                  .toString(),
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: smallSize,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      song.duration == 0
                                                          ? "??:??"
                                                          : "${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2, '0')}",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: normalSize,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          itemCount: songs.length,
                                          onReorder: (
                                            int oldIndex,
                                            int newIndex,
                                          ) {
                                            // if (oldIndex < newIndex) {
                                            //   newIndex -= 1;
                                            // }
                                            // var temp = widget.playlist.pathsInOrder.removeAt(oldIndex);
                                            // widget.playlist.pathsInOrder.insert(newIndex, temp);
                                            // DataController.playlistBox.put(widget.playlist);
                                            // orderChanged.value = !orderChanged.value;
                                          },
                                        );
                                      },
                                    ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: width * 0.025),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
