import 'dart:async';

import 'package:flutter/material.dart';
import 'package:musicplayer/components/custom_tiling/grid_component.dart';
import 'package:musicplayer/entities/album.dart';
import 'package:musicplayer/providers/albums_provider.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/audio_provider.dart';
import 'package:musicplayer/screens/add_or_export_screen.dart';
import 'package:musicplayer/screens/album_screen.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';


class Albums extends StatefulWidget{
  static Route<dynamic> route() {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/albums'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Albums();
      },
    );
  }
  const Albums({super.key});

  @override
  State<Albums> createState() => _AlbumsState();
}


class _AlbumsState extends State<Albums>{
  ValueNotifier<List<Album>> selected = ValueNotifier<List<Album>>([]);
  FocusNode searchNode = FocusNode();
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    // var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Scaffold(
      body: Container(
        padding: EdgeInsets.only(
            top: height * 0.02,
            left: width * 0.01,
            right: width * 0.01,
            bottom: height * 0.02
        ),
        child: Consumer<AlbumProvider>(
          builder: (_, albumProvider, __) {
            return Column(
              children: [
                Container(
                  height: height * 0.05,
                  margin: EdgeInsets.only(
                    left: width * 0.01,
                    right: width * 0.01,
                    bottom: height * 0.01,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          focusNode: searchNode,
                          onChanged: (value) {
                            if (_debounce?.isActive ?? false) _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              albumProvider.setQuery(value);
                            });
                          },
                          cursorColor: Colors.white,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: normalSize,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(width * 0.02),
                              borderSide: const BorderSide(
                                color: Colors.white,
                              ),
                            ),
                            contentPadding: EdgeInsets.only(
                              left: width * 0.01,
                              right: width * 0.01,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontSize: smallSize,
                            ),
                            labelText: 'Search',
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.white, size: height * 0.03),
                              onPressed: () {
                                _controller.clear();
                                albumProvider.setQuery("");
                                searchNode.unfocus();
                              },
                            )
                                : Icon(FluentIcons.search, color: Colors.white, size: height * 0.03),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width * 0.01,
                      ),
                      Container(
                        padding: EdgeInsets.only(
                          left: width * 0.01,
                          right: width * 0.01,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                albumProvider.setSortField(value);
                              },
                              tooltip: "Sort by",
                              itemBuilder: (context) => [
                                PopupMenuItem(value: "Name", child: Text("Name")),
                                PopupMenuItem(value: "Duration", child: Text("Duration")),
                                PopupMenuItem(value: "Number of Songs", child: Text("Number of Songs")),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  albumProvider.sortField,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: smallSize,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1, // Divider thickness
                              height: double.maxFinite, // Divider height
                              margin: EdgeInsets.only(
                                right: width * 0.01,
                                left: width * 0.01,
                              ),
                              color: Colors.grey,
                            ),
                            IconButton(
                              icon: Icon(albumProvider.isAscending ? FluentIcons.sortAscending : FluentIcons.sortDescending),
                              onPressed: () {
                                albumProvider.setFlag(!albumProvider.isAscending);
                                debugPrint("Sort order set to ${albumProvider.isAscending}");
                              },
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder(
                      future: albumProvider.albumsFuture,
                      builder: (context, snapshot){
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint(snapshot.error.toString());
                          debugPrintStack();
                          return Center(
                            child: Text(
                              "Error loading albums",
                              style: TextStyle(color: Colors.white, fontSize: smallSize),
                            ),
                          );
                        }
                        debugPrint("Albums loaded: ${snapshot.data?.length ?? 0}");
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
                                            selected.value = List<Album>.from(selected.value)..remove(entity);
                                          } else {
                                            selected.value = List<Album>.from(selected.value)..add(entity);
                                          }
                                          return;
                                        }
                                        var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                                        appStateProvider.navigatorKey.currentState!.push(AlbumScreen.route(album: entity));
                                      } else {
                                        debugPrint("Entity is not an Album");
                                      }
                                    },
                                    onLongPress: (entity) {
                                      debugPrint("long pressed ${entity.name}");
                                      if (entity is Album) {
                                        if (selected.value.contains(entity)) {
                                          selected.value = List<Album>.from(selected.value)..remove(entity);
                                        } else {
                                          selected.value = List<Album>.from(selected.value)..add(entity);
                                        }
                                      }
                                    },
                                    buildLeftAction: (entity) {
                                      if (selected.value.contains(entity)) {
                                        return SizedBox.shrink();
                                      }
                                      return IconButton(
                                        icon: Icon(FluentIcons.play, color: Colors.white, size: height * 0.025),
                                        onPressed: () async {
                                          debugPrint("Playing album ${entity.name}");
                                          if (entity is! Album) {
                                            debugPrint("Entity is not an Album");
                                            return;
                                          }
                                          Album album = entity;
                                          album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
                                          List<String> songPaths = album.songs.map((e) => e.path).toList();
                                          var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                          audioProvider.setQueue(songPaths);
                                          await audioProvider.setCurrentIndex(album.songs.first.path);
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
                                          switch(value){
                                            case 'add':
                                              Album album = entity as Album;
                                              album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
                                              var appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
                                              appStateProvider.navigatorKey.currentState!.push(
                                                  AddOrExportScreen.route(songs: album.songs)
                                              );
                                              break;
                                            case 'playNext':
                                              Album album = entity as Album;
                                              album.songs.sort((a, b) => b.trackNumber.compareTo(a.trackNumber));
                                              var audioProvider = Provider.of<AudioProvider>(context, listen: false);
                                              audioProvider.addMultipleNextToQueue(
                                                album.songs.map((e) => e.path).toList(),
                                              );
                                              break;
                                            case 'select':
                                              Album album = entity as Album;
                                              if (selected.value.contains(album)) {
                                                selected.value = List<Album>.from(selected.value)..remove(album);
                                              } else {
                                                selected.value = List<Album>.from(selected.value)..add(album);
                                              }
                                              break;
                                          }
                                        },
                                        itemBuilder: (context){
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
                                    }
                                  );
                                }
                              ),
                            ),
                          ],
                        );
                      }
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterFloat,
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
                borderRadius: BorderRadius.circular(30),
              ),
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(FluentIcons.add, color: Colors.white, size: MediaQuery.of(context).size.height * 0.02,),
                      label: Text(
                        "Add",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: normalSize,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () async {
                        debugPrint("Add button pressed");
                        if (selected.value.isEmpty) {
                          return;
                        }
                        var appState = Provider.of<AppStateProvider>(context, listen: false);
                        var songs = selected.value.expand((album) {
                          album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
                          return album.songs;
                        }).toList();
                        appState.navigatorKey.currentState?.push(
                          AddOrExportScreen.route(songs: songs),
                        ).then((value) {
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
                            )
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
                          )
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