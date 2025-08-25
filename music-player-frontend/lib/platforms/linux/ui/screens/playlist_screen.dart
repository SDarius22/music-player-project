import 'dart:convert';

import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/components/custom_tiling/list_component.dart';
import 'package:musicplayer/entities/song.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/audio_provider.dart';
import 'package:musicplayer/providers/playlist_provider.dart';
import 'package:musicplayer/screens/add_or_export_screen.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:musicplayer/entities/playlist.dart';
import 'package:musicplayer/components/image_widget.dart';
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

  @override
  void initState() {
    super.initState();
    final orderMap = {for (int i = 0; i < widget.playlist.pathsInOrder.length; i++) widget.playlist.pathsInOrder[i]: i};

    widget.playlist.songs.sort((a, b) {
      return (orderMap[a.path] ?? widget.playlist.pathsInOrder.length)
          .compareTo(orderMap[b.path] ?? widget.playlist.pathsInOrder.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Scaffold(
      body: Container(
        padding: EdgeInsets.only(
            top: height * 0.02,
            left: width * 0.01,
            right: width * 0.01,
            bottom: height * 0.125
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: (){
                    debugPrint("Back");
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    FluentIcons.back,
                    size: height * 0.02,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.playlist.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: boldSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.playlist.indestructible == false)
                  SizedBox(
                    width: width * 0.06,
                    child: ValueListenableBuilder(
                        valueListenable: editMode,
                        builder: (context, value, child){
                          return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                              ),
                              onPressed: (){
                                debugPrint("Edit ${widget.playlist.name}");
                                if(editMode.value == false){
                                  editMode.value = true;
                                }
                                else{
                                  editMode.value = false;
                                  // DataController.playlistBox.put(widget.playlist);
                                }
                              },
                              child: Text(
                                value ? "Done" : "Edit",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize
                                ),
                              )
                          );
                        }
                    ),
                  ),

              ],
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.05,
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Hero(
                              tag: widget.playlist.name,
                              child: ValueListenableBuilder(
                                  valueListenable: editMode,
                                  builder: (context, value, child){
                                    return Container(
                                      height: height * 0.5,
                                      width: height * 0.5,
                                      padding: EdgeInsets.only(
                                        bottom: height * 0.01,
                                      ),
                                      //color: Colors.red,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(width * 0.025),
                                        child: ImageWidget(
                                          type: widget.playlist.coverArt != null && widget.playlist.coverArt!.isNotEmpty
                                              ? ImageWidgetType.bytes
                                              : ImageWidgetType.song,
                                          path: widget.playlist.coverArt != null && widget.playlist.coverArt!.isNotEmpty
                                            ? base64Encode(widget.playlist.coverArt!)
                                            : widget.playlist.songs.isNotEmpty
                                            ? widget.playlist.songs.first.path
                                            : '',
                                        ),

                                      ),
                                    );
                                  }
                              ),
                            ),
                            ValueListenableBuilder(
                              valueListenable: editMode,
                              builder: (context, value, child){
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: value == false ?
                                  Text(
                                    widget.playlist.name,
                                    key: const ValueKey("Playlist Name"),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: boldSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ) :
                                  SizedBox(
                                      key: const ValueKey("Playlist Name Edit"),
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
                                            borderRadius: BorderRadius.circular(width * 0.005),
                                          ),
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: normalSize,
                                        ),
                                        onChanged: (value){
                                          widget.playlist.name = value;
                                        },
                                      )
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
                            SizedBox(
                              height: height * 0.005,
                            ),
                            Text(
                              Duration(seconds: widget.playlist.duration,).pretty(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: smallSize,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            SizedBox(
                              height: height * 0.005,
                            ),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      List<String> songPaths = widget.playlist.songs.map((e) => e.path).toList();
                                      var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                      audioProvider.setQueue(songPaths);
                                      await audioProvider.setCurrentIndex(widget.playlist.songs.first.path);
                                    },
                                    icon: Icon(
                                      FluentIcons.play,
                                      color: Colors.white,
                                      size: height * 0.025,
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: (){
                                      debugPrint("Add ${widget.playlist.name}");
                                      var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                                      appStateProvider.navigatorKey.currentState?.push(AddOrExportScreen.route(songs: widget.playlist.songs));
                                    },
                                    icon: Icon(
                                      FluentIcons.add,
                                      color: Colors.white,
                                      size: height * 0.025,
                                    ),
                                  ),
                                  if (widget.playlist.indestructible == false)
                                    IconButton(
                                      onPressed: () {
                                        debugPrint("Delete ${widget.playlist.name}");
                                        var playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
                                        playlistProvider.deletePlaylist(widget.playlist);
                                        Navigator.pop(context);
                                      },
                                      icon: Icon(
                                        FluentIcons.trash,
                                        color: Colors.white,
                                        size: height * 0.025,
                                      ),
                                    ),

                                ]
                            ),

                          ]
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(width * 0.01),
                      margin: EdgeInsets.only(
                        top: height * 0.02,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * 0.02),
                        color: const Color(0xFF242424),
                      ),
                      child: ValueListenableBuilder(
                        valueListenable: editMode,
                        builder: (context, value, child){
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            reverseDuration: const Duration(milliseconds: 500),
                            child: value == false ?
                            CustomScrollView(
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    bottom: height * 0.02,
                                  ),
                                  sliver: ListComponent(
                                    items: widget.playlist.songs,
                                    itemExtent: height * 0.125,
                                    isSelected: (entity) {
                                      return false;
                                    },
                                    onTap: (entity) async {
                                      debugPrint("Tapped on ${entity.name}");
                                      List<String> songPaths = widget.playlist.songs.map((e) => e.path).toList();
                                      var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                      audioProvider.setQueue(songPaths);
                                      await audioProvider.setCurrentIndex((entity as Song).path);
                                    },
                                    onLongPress: (entity) {
                                      debugPrint("Long pressed on ${entity.name}");
                                      // Show context menu or options
                                    },
                                  ),
                                ),
                              ],
                            ) :
                            ValueListenableBuilder(
                                valueListenable: orderChanged,
                                builder: (context, value2, child){
                                  return ReorderableListView.builder(
                                    key: const ValueKey("Edit List"),
                                    padding: EdgeInsets.only(
                                      right: width * 0.01,
                                    ),
                                    itemBuilder: (context, int index) {
                                      //debugPrint("Building ${widget.playlist. songs.value[widget.playlist.order[index]].title}");
                                      Song song =  widget.playlist.songs[index];
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
                                            borderRadius: BorderRadius.circular(width * 0.01),
                                            color: const Color(0xFF0E0E0E),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                  borderRadius: BorderRadius.circular(width * 0.01),
                                                  child: ImageWidget(
                                                    path: song.path,
                                                    type: ImageWidgetType.song,
                                                    hoveredChild: IconButton(
                                                      onPressed: (){
                                                        widget.playlist.pathsInOrder.removeAt(index);
                                                        orderChanged.value = !orderChanged.value;
                                                      },
                                                      icon: Icon(
                                                        FluentIcons.trash,
                                                        color: Colors.white,
                                                        size: height * 0.02,
                                                      ),

                                                    ),
                                                  )
                                              ),
                                              SizedBox(
                                                width: width * 0.01,
                                              ),
                                              Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        song.name.toString().length > 60 ? "${song.name.toString().substring(0, 60)}..." : song.name.toString(),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: normalSize,
                                                        )
                                                    ),
                                                    SizedBox(
                                                      height: height * 0.001,
                                                    ),
                                                    Text(song.trackArtist.toString().length > 60 ? "${song.trackArtist.toString().substring(0, 60)}..." : song.trackArtist.toString(),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: smallSize,
                                                        )
                                                    ),
                                                  ]
                                              ),
                                              const Spacer(),
                                              Text(
                                                  song.duration == 0 ? "??:??" : "${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2, '0')}",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: normalSize,
                                                  )
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    itemCount: widget.playlist.pathsInOrder.length,
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
                                }
                            ),

                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width * 0.025,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}