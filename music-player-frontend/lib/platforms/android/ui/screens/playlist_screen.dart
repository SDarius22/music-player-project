import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class PlaylistScreen extends EntityScreen {
  static Route<void> route({required Playlist playlist}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/playlist', arguments: Playlist),
      pageBuilder: (context, animation, secondaryAnimation) {
        return PlaylistScreen(entity: playlist as BaseEntity);
      },
    );
  }

  const PlaylistScreen({super.key, required super.entity});

  @override
  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.only(bottom: height * 0.01);
  }

  @override
  Widget buildBody(BuildContext context, double width, double height) {
    var playlist = entity as Playlist;
    List<Song> songs = playlist.songsList;
    ValueNotifier<bool> editMode = ValueNotifier<bool>(false);
    ValueNotifier<bool> orderChanged = ValueNotifier<bool>(false);

    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;

    return Column(
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
                  var audioProvider = Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  );
                  audioProvider.setQueue(songs);
                  await audioProvider.setCurrentSongAndPlay(songs.first);
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
              if (playlist.indestructible == false)
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
                          debugPrint("Edit ${playlist.name}");
                          if (editMode.value == false) {
                            editMode.value = true;
                          } else {
                            editMode.value = false;
                            // DataController.playlistBox.put(playlist);
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: height * 0.02),
              Hero(
                tag: playlist.name,
                child: ValueListenableBuilder(
                  valueListenable: editMode,
                  builder: (context, value, child) {
                    return Container(
                      height: width * 0.6,
                      width: width * 0.6,
                      padding: EdgeInsets.only(bottom: height * 0.01),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.height * 0.015,
                        ),
                        child: ImageWidget(entity: playlist),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: height * 0.02),
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
                              style: TextStyle(
                                fontSize: boldSize,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : SizedBox(
                              key: const ValueKey("Playlist Name Edit"),
                              width: width * 0.7,
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
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: normalSize,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
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
                                  playlist.name = value;
                                },
                              ),
                            ),
                  );
                },
              ),
              SizedBox(height: height * 0.02),
            ],
          ),
        ),
        Expanded(
          child: GlassContainer(
            margin: EdgeInsets.symmetric(horizontal: width * 0.05),
            padding: EdgeInsets.only(
              right: width * 0.01,
              top: height * 0.01,
              bottom: height * 0.01,
            ),
            color: Colors.black.withValues(alpha: 0.4),
            borderGradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.60),
                Colors.indigoAccent.withValues(alpha: 0.6),
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
            shadowColor: Colors.black.withValues(alpha: 0.20),
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
                                padding: EdgeInsets.only(bottom: height * 0.02),
                                sliver: ListComponent(
                                  items: songs,
                                  itemExtent: height * 0.125,
                                  isSelected: (entity) {
                                    return false;
                                  },
                                  onTap: (entity) async {
                                    debugPrint("Tapped on ${entity.name}");
                                    var audioProvider =
                                        Provider.of<AudioProvider>(
                                          context,
                                          listen: false,
                                        );
                                    audioProvider.setQueue(songs);
                                    await audioProvider.setCurrentSongAndPlay(
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
                                padding: EdgeInsets.only(right: width * 0.01),
                                itemBuilder: (context, int index) {
                                  //debugPrint("Building ${widget.playlist. songs.value[widget.playlist.order[index]].title}");
                                  Song song = songs[index];
                                  return AnimatedContainer(
                                    key: Key('$index'),
                                    duration: const Duration(milliseconds: 500),
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
                                                  // widget
                                                  //     .playlist
                                                  //     .pathsInOrder
                                                  //     .removeAt(
                                                  //       index,
                                                  //     );
                                                  orderChanged.value =
                                                      !orderChanged.value;
                                                },
                                                icon: Icon(
                                                  FluentIcons.trash,
                                                  color: Colors.white,
                                                  size: height * 0.02,
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
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: normalSize,
                                                ),
                                              ),
                                              SizedBox(height: height * 0.001),
                                              Text(
                                                song.artist.toString().length >
                                                        60
                                                    ? "${song.artist.toString().substring(0, 60)}..."
                                                    : song.artist.toString(),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: smallSize,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            song.durationInSeconds == 0
                                                ? "??:??"
                                                : "${song.durationInSeconds ~/ 60}:${(song.durationInSeconds % 60).toString().padLeft(2, '0')}",
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
                                onReorder: (int oldIndex, int newIndex) {
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
      ],
    );
  }
}
