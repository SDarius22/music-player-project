import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:provider/provider.dart';

class CreateOrImportScreen extends AbstractCreateOrImportScreen {
  static Route<void> route({
    String playlistName = "",
    List<String> playlistPaths = const [],
    bool import = false,
  }) {
    return PageRouteBuilder(
      settings: const RouteSettings(arguments: [String, List<String>, bool]),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CreateOrImportScreen(
          playlistName: playlistName,
          playlistPaths: playlistPaths,
          import: import,
        );
      },
    );
  }

  const CreateOrImportScreen({
    super.key,
    super.playlistName = "",
    super.playlistPaths = const [],
    super.import = false,
  });

  @override
  AbstractCreateOrImportScreenState createState() =>
      _CreateOrImportScreenState();
}

class _CreateOrImportScreenState
    extends AbstractCreateOrImportScreenState<CreateOrImportScreen> {
  String encodeImage(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.only(bottom: height * 0.01);
  }

  @override
  Widget buildBody(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    //var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
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
            Text(
              widget.import ? "Import a playlist" : "Create a new playlist",
              style:
                  MusicPlayerTheme.getTheme(
                    context,
                    context.read<Scaler>(),
                  ).textTheme.bodyMedium,
            ),
            const Spacer(),
            SizedBox(
              width: width * 0.06,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.01),
                ),
                onPressed: () {
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
                  var playlistProvider = Provider.of<PlaylistProvider>(
                    context,
                    listen: false,
                  );
                  playlistProvider.addPlaylist(
                    playlistName,
                    selected.value,
                    playlistAdd,
                    coverArt.value ?? Constants.logoBytes,
                  );
                  BotToast.showText(
                    text:
                        widget.import
                            ? "Playlist imported successfully"
                            : "Playlist created successfully",
                    duration: const Duration(seconds: 3),
                  );
                  Navigator.pop(context);
                },
                child: Text(
                  "Done",
                  style: TextStyle(color: Colors.white, fontSize: normalSize),
                ),
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
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.height * 0.015,
                        ),
                        child: Container(
                          width: width * 0.3,
                          height: width * 0.3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
                            color: Colors.black,
                          ),
                          child: MultiValueListenableBuilder(
                            valueListenables: [coverArt, selected],
                            builder: (context, values, child) {
                              debugPrint(
                                "something changed in cover art or selected songs",
                              );
                              var cover = values[0] as Uint8List?;
                              if (cover != null) {
                                debugPrint(
                                  "Cover art is not null, length: ${cover.length}",
                                );
                                return ImageWidget(
                                  imageBytes: cover,
                                  hoveredChild: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: () async {
                                          debugPrint("Change cover art");
                                          var appStates = Provider.of<
                                            AbstractAppStateProvider
                                          >(context, listen: false);
                                          FilePickerResult? result =
                                              await FilePicker.platform
                                                  .pickFiles(
                                                    initialDirectory:
                                                        appStates
                                                            .appSettings
                                                            .mainSongPlace,
                                                    type: FileType.image,
                                                    allowMultiple: false,
                                                  );

                                          if (result != null &&
                                              result.files.isNotEmpty) {
                                            debugPrint(
                                              "Picked file: ${result.files.single.name}",
                                            );
                                            File file = File(
                                              result.files.single.path!,
                                            );
                                            Uint8List imageBytes =
                                                file.readAsBytesSync();
                                            coverArt.value = imageBytes;
                                            debugPrint(
                                              "Cover art set successfully",
                                            );
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
                                          coverArt.value = Constants.logoBytes;
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
                              var selectedSongs = values[1] as List<Song>;
                              return ImageWidget(
                                imageBytes:
                                    selectedSongs.isNotEmpty
                                        ? (selectedSongs.first).coverArt
                                        : Constants.logoBytes,
                                hoveredChild: IconButton(
                                  onPressed: () async {
                                    debugPrint("Change cover art");
                                    var appStates =
                                        Provider.of<AbstractAppStateProvider>(
                                          context,
                                          listen: false,
                                        );
                                    FilePickerResult? result = await FilePicker
                                        .platform
                                        .pickFiles(
                                          initialDirectory:
                                              appStates
                                                  .appSettings
                                                  .mainSongPlace,
                                          type: FileType.image,
                                          allowMultiple: false,
                                        );

                                    if (result != null &&
                                        result.files.isNotEmpty) {
                                      debugPrint(
                                        "Picked file: ${result.files.single.name}",
                                      );
                                      File file = File(
                                        result.files.single.path!,
                                      );
                                      Uint8List imageBytes =
                                          file.readAsBytesSync();
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
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.02),
                      TextFormField(
                        maxLength: 50,
                        initialValue: playlistName,
                        decoration: InputDecoration(
                          border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
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
                          Text(
                            "Where to add new songs in the future?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
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
                            underline: Container(height: 0),
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
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
                            onChanged: (String? newValue) {
                              setState(() {
                                playlistAdd = newValue ?? 'last';
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(width * 0.01),
                  margin: EdgeInsets.only(top: height * 0.02),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.height * 0.015,
                    ),
                    color: const Color(0xFF242424),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextFormField(
                        focusNode: searchNode,
                        onChanged: (value) {
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
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontSize: smallSize,
                          ),
                          labelText: 'Search',
                          suffixIcon: Icon(
                            FluentIcons.search,
                            color: Colors.white,
                            size: height * 0.02,
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.02),
                      Expanded(
                        child: Consumer<SongProvider>(
                          builder: (context, songProvider, child) {
                            return FutureBuilder(
                              future: Future(
                                () =>
                                    songProvider.getSongs(search, "Name", true),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  debugPrint(snapshot.error.toString());
                                  debugPrintStack();
                                  return Center(
                                    child: Text(
                                      "Error loading songs",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: smallSize,
                                      ),
                                    ),
                                  );
                                }
                                debugPrint(
                                  "Songs loaded: ${snapshot.data?.length ?? 0}",
                                );
                                if ((snapshot.data ?? []).isEmpty) {
                                  return Center(
                                    child: Text(
                                      "No songs found",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: smallSize,
                                      ),
                                    ),
                                  );
                                }
                                return CustomScrollView(
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.zero,
                                      sliver: ValueListenableBuilder<
                                        List<Song>
                                      >(
                                        valueListenable: selected,
                                        builder: (
                                          context,
                                          selectedSongs,
                                          child,
                                        ) {
                                          return LinuxListComponent(
                                            items: snapshot.data ?? [],
                                            itemExtent: height * 0.125,
                                            isSelected: (entity) {
                                              return selected.value.contains(
                                                (entity as Song),
                                              );
                                            },
                                            onTap: (entity) {
                                              debugPrint(
                                                "Tapped on ${entity.name}",
                                              );
                                              if (selected.value.contains(
                                                (entity as Song),
                                              )) {
                                                selected.value = List.from(
                                                  selected.value,
                                                )..remove(entity);
                                              } else {
                                                selected.value = List.from(
                                                  selected.value,
                                                )..add(entity);
                                              }
                                            },
                                            onLongPress: (entity) {
                                              debugPrint(
                                                "Long pressed on ${entity.name}",
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: width * 0.025),
            ],
          ),
        ),
      ],
    );
  }
}
