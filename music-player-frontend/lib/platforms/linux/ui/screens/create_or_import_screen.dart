import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:musicplayer/components/custom_tiling/list_component.dart';
import 'package:musicplayer/components/image_widget.dart';
import 'package:musicplayer/entities/song.dart';
import 'package:musicplayer/providers/app_state_provider.dart';
import 'package:musicplayer/providers/playlist_provider.dart';
import 'package:musicplayer/providers/song_provider.dart';
import 'package:musicplayer/utils/fluenticons/fluenticons.dart';
import 'package:flutter/material.dart';
import 'package:musicplayer/utils/multivaluelistenablebuilder/mvlb.dart';
import 'package:provider/provider.dart';



class CreateOrImportScreen extends StatefulWidget {
  final String playlistName;
  final List<String> playlistPaths;
  final bool import;


  static Route<void> route({String playlistName = "", List<String> playlistPaths = const [], bool import = false}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/create', arguments: [String, List<String>, bool]),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CreateOrImportScreen(
          playlistName: playlistName,
          playlistPaths: playlistPaths,
          import: import,
        );
      },
    );
  }

  const CreateOrImportScreen({super.key, this.playlistName = "", this.playlistPaths = const [], this.import = false});

  @override
  State<CreateOrImportScreen> createState() => _CreateOrImportScreenState();
}

class _CreateOrImportScreenState extends State<CreateOrImportScreen> {
  ValueNotifier<List<String>> selected = ValueNotifier<List<String>>([]);
  String playlistName = "";
  String playlistAdd = "last";
  String search = "";
  ValueNotifier<Uint8List?> coverArt = ValueNotifier<Uint8List?>(null);
  FocusNode searchNode = FocusNode();
  FocusNode nameNode = FocusNode();

  @override
  void initState() {
    var name = widget.playlistName;
    var paths = widget.playlistPaths;
    playlistName = name;
    if (paths.isNotEmpty) {
      if (widget.import) {
        var songProvider = Provider.of<SongProvider>(context, listen: false);
        selected.value = paths.map((path) {
          var song = songProvider.getSongContaining(path);
          if (song != null) {
            return song.path;
          } else {
            return path;
          }
        }).toList();
      } else {
        selected.value = List.from(paths);
      }
    }
    super.initState();
    nameNode.requestFocus();
  }

  String encodeImage(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    //var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Scaffold(
      body: Container(
        width: width,
        height: height,
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
                  widget.import ? "Import a playlist" : "Create a new playlist",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: normalSize
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: width * 0.06,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                      ),
                      onPressed: (){
                        if (playlistName.isEmpty) {
                          BotToast.showText(
                            text: "Playlist name cannot be empty",
                            duration: const Duration(seconds: 3),
                          );
                          return;
                        }
                        if (selected.value.isEmpty) {
                          BotToast.showText(
                            text: "You must select at least one song",
                            duration: const Duration(seconds: 3),
                          );
                          return;
                        }
                        debugPrint("Create new playlist");
                        var playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
                        playlistProvider.addPlaylist(playlistName, selected.value, playlistAdd, coverArt.value);
                        BotToast.showText(
                          text: widget.import ? "Playlist imported successfully" : "Playlist created successfully",
                          duration: const Duration(seconds: 3),
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Done",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: normalSize
                        ),
                      )
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
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(width * 0.02),
                            child: Container(
                              width: width * 0.3,
                              height: width * 0.3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(width * 0.02),
                                color: Colors.black,
                              ),
                              child: MultiValueListenableBuilder(
                                  valueListenables: [coverArt, selected],
                                  builder: (context, values, child) {
                                    debugPrint("something changed in cover art or selected songs");
                                    var cover = values[0] as Uint8List?;
                                    if (cover != null) {
                                      debugPrint("Cover art is not null, length: ${cover.length}");
                                      return ImageWidget(
                                        path: encodeImage(cover),
                                        type: ImageWidgetType.bytes,
                                        hoveredChild: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              onPressed: () async {
                                                debugPrint("Change cover art");
                                                var appStates = Provider.of<AppStateProvider>(context, listen: false);
                                                FilePickerResult? result = await FilePicker.platform.pickFiles(initialDirectory: appStates.appSettings.mainSongPlace, type: FileType.image, allowMultiple: false);

                                                if (result != null && result.files.isNotEmpty){
                                                  debugPrint("Picked file: ${result.files.single.name}");
                                                  File file = File(result.files.single.path!);
                                                  Uint8List imageBytes = file.readAsBytesSync();
                                                  coverArt.value = imageBytes;
                                                  debugPrint("Cover art set successfully");
                                                } else {
                                                  debugPrint("No file selected");
                                                }
                                              },
                                              icon: Icon(
                                                Icons.camera_alt_outlined,
                                                color: Colors.white,
                                                size: height * 0.05,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                debugPrint("Remove cover art");
                                                coverArt.value = null;
                                              },
                                              icon: Icon(
                                                FluentIcons.trash,
                                                color: Colors.white,
                                                size: height * 0.05,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    var value = values[1] as List<String>;
                                    return ImageWidget(
                                      path: value.isEmpty ? '' : value.first,
                                      type: ImageWidgetType.song,
                                      hoveredChild: IconButton(
                                        onPressed: () async {
                                          debugPrint("Change cover art");
                                          var appStates = Provider.of<AppStateProvider>(context, listen: false);
                                          FilePickerResult? result = await FilePicker.platform.pickFiles(initialDirectory: appStates.appSettings.mainSongPlace, type: FileType.image, allowMultiple: false);

                                          if (result != null && result.files.isNotEmpty){
                                            debugPrint("Picked file: ${result.files.single.name}");
                                            File file = File(result.files.single.path!);
                                            Uint8List imageBytes = file.readAsBytesSync();
                                            coverArt.value = imageBytes;
                                            debugPrint("Cover art set successfully");
                                          } else {
                                            debugPrint("No file selected");
                                          }
                                        },
                                        icon: Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.white,
                                          size: height * 0.05,
                                        ),
                                      ),
                                    );
                                  }
                              ),
                            ),
                          ),
                          SizedBox(
                            height: height * 0.02,
                          ),
                          TextFormField(
                            maxLength: 50,
                            initialValue: playlistName,
                            decoration: InputDecoration(
                              border: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              hintText: 'Playlist name',
                              counterText: "",
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: smallSize,
                              ),
                            ),
                            cursorColor: Colors.white,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                            ),
                            onChanged: (value) {
                              playlistName = value;
                            },
                          ),
                          Row(
                            children: [
                              Text("Where to add new songs in the future?",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: normalSize
                                ),
                              ),
                              const Spacer(),
                              DropdownButton<String>(
                                  value: playlistAdd,
                                  icon: Icon(
                                    FluentIcons.down,
                                    color: Colors.white,
                                    size: height * 0.025,
                                  ),
                                  style: TextStyle(
                                    fontSize: normalSize,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                  underline: Container(
                                    height: 0,
                                  ),
                                  borderRadius: BorderRadius.circular(width * 0.01),
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.center,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'first',
                                      child: Text("At the beginning"),
                                    ),
                                    DropdownMenuItem(
                                      value: 'last',
                                      child: Text("At the end"),
                                    ),
                                  ],
                                  onChanged: (String? newValue){
                                    setState(() {
                                      playlistAdd = newValue ?? 'last';
                                    });
                                  }
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(width * 0.01),
                      margin: EdgeInsets.only(
                        top: height * 0.02,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(width * 0.02),
                        color: const Color(0xFF242424),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextFormField(
                            focusNode: searchNode,
                            onChanged: (value){
                              setState(() {
                                search = value;
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
                                labelStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: smallSize,
                                ),
                                labelText: 'Search', suffixIcon: Icon(FluentIcons.search, color: Colors.white, size: height * 0.02,)
                            ),
                          ),
                          SizedBox(
                            height: height * 0.02,
                          ),
                          Expanded(
                            child: Consumer<SongProvider>(
                              builder: (context, songProvider, child) {
                                return FutureBuilder(
                                    future: Future(() => songProvider.getSongs(search, "Name", false),),
                                    builder: (context, snapshot) {
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
                                            "Error loading songs",
                                            style: TextStyle(color: Colors.white, fontSize: smallSize),
                                          ),
                                        );
                                      }
                                      debugPrint("Songs loaded: ${snapshot.data?.length ?? 0}");
                                      return CustomScrollView(
                                        slivers: [
                                          SliverPadding(
                                            padding: EdgeInsets.zero,
                                            sliver: ValueListenableBuilder<List<String>>(
                                              valueListenable: selected,
                                              builder: (context, selectedSongs, child) {
                                                return ListComponent(
                                                  items: snapshot.data ?? [],
                                                  itemExtent: height * 0.125,
                                                  isSelected: (entity) {
                                                    return selected.value.contains((entity as Song).path);
                                                  },
                                                  onTap: (entity) {
                                                    debugPrint("Tapped on ${entity.name}");
                                                    if (selected.value.contains((entity as Song).path)) {
                                                      selected.value = List.from(selected.value)..remove(entity.path);
                                                    } else {
                                                      selected.value = List.from(selected.value)..add(entity.path);
                                                    }
                                                  },
                                                  onLongPress: (entity) {
                                                    debugPrint("Long pressed on ${entity.name}");
                                                  },
                                                );
                                              },
                                            ),
                                          )
                                        ],
                                      );
                                    }
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width * 0.025,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}