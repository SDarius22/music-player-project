import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class CreateOrImportScreen extends StatefulWidget {
  static Route<void> route({
    String playlistName = "",
    List<String> playlistPaths = const [],
    bool import = false,
  }) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => CreateOrImportScreen(
        playlistName: playlistName,
        playlistPaths: playlistPaths,
        import: import,
      ),
      settings: RouteSettings(name: import ? "/import" : "/create"),
    );
  }

  final String playlistName;
  final List<String> playlistPaths;
  final bool import;

  const CreateOrImportScreen({
    super.key,
    this.playlistName = "",
    this.playlistPaths = const [],
    this.import = false,
  });

  @override
  State<CreateOrImportScreen> createState() => _CreateOrImportScreenState();
}

class _CreateOrImportScreenState extends State<CreateOrImportScreen> {
  late ValueNotifier<List<Song>> selected;
  late String playlistName;
  late String playlistAdd;
  late String search;
  late ValueNotifier<Uint8List?> coverArt;
  late FocusNode searchNode;
  late FocusNode nameNode;

  @override
  void initState() {
    super.initState();
    selected = ValueNotifier<List<Song>>([]);
    playlistName = widget.playlistName;
    playlistAdd = "last";
    search = "";
    coverArt = ValueNotifier<Uint8List?>(null);
    searchNode = FocusNode();
    nameNode = FocusNode();

    initializeSelectedSongs();
    nameNode.requestFocus();
  }

  @override
  void dispose() {
    selected.dispose();
    coverArt.dispose();
    searchNode.dispose();
    nameNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(padding: buildPadding(context), child: buildBody(context)),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const PreferredSize(
      preferredSize: Size.fromHeight(0),
      child: SizedBox.shrink(),
    );
  }

  void initializeSelectedSongs() {
    if (widget.playlistPaths.isEmpty) return;

    if (widget.import) {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      selected.value =
          widget.playlistPaths
              .map((path) => songProvider.getSongContaining(path))
              .whereType<Song>()
              .toList();
      if (selected.value.isNotEmpty) {
        coverArt.value = selected.value.first.coverArt;
      }
    } else {
      selected.value = List.from(widget.playlistPaths);
    }
  }

  void handleCreatePlaylist() {
    if (playlistName.isEmpty) {
      showToast("Playlist name cannot be empty");
      return;
    }
    if (selected.value.isEmpty) {
      showToast("You must select at least one song");
      return;
    }

    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    playlistProvider.addPlaylist(
      playlistName,
      selected.value,
      playlistAdd,
      coverArt.value,
    );

    showToast(
      widget.import
          ? "Playlist imported successfully"
          : "Playlist created successfully",
    );
    Navigator.pop(context);
  }

  void toggleSongSelection(Song song) {
    if (selected.value.contains(song)) {
      selected.value = List.from(selected.value)..remove(song);
    } else {
      selected.value = List.from(selected.value)..add(song);
    }
  }

  void showToast(String message, {int durationSeconds = 2}) {
    BotToast.showText(
      text: message,
      duration: Duration(seconds: durationSeconds),
    );
  }

  String encodeImage(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }

  Future<void> _pickCoverArt() async {
    var appStates = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      initialDirectory: kIsWeb ? null : appStates.appSettings.mainSongPlace,
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        coverArt.value = bytes;
      }
    }
  }

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return EdgeInsets.only(bottom: height * 0.01);
  }

  Widget buildBody(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
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
              icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            Text(
              widget.import ? "Import a playlist" : "Create a new playlist",
              style: Theme.of(context).textTheme.bodyMedium,
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
                    coverArt.value,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: Colors.white),
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
                              var cover = values[0] as Uint8List?;
                              if (cover != null) {
                                var playlist = Playlist();
                                playlist.imageBytes = cover;

                                return ImageWidget(
                                  entity: playlist,
                                  hoveredChild: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: _pickCoverArt,
                                        icon: Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          coverArt.value = null;
                                        },
                                        icon: Icon(
                                          FluentIcons.trash,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              var selectedSongs = values[1] as List<Song>;
                              if (selectedSongs.isEmpty) {
                                return Container(
                                  color: Colors.black,
                                  child: Icon(
                                    FluentIcons.music,
                                    color: Colors.white.withValues(alpha: 0.25),
                                    size: 64,
                                  ),
                                );
                              }
                              return ImageWidget(
                                entity: selectedSongs.first,
                                hoveredChild: IconButton(
                                  onPressed: _pickCoverArt,
                                  icon: Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 48,
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
                          hintStyle: Theme.of(
                            context,
                          ).textTheme.bodySmall!.copyWith(color: Colors.grey),
                        ),
                        cursorColor: Colors.white,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                        onChanged: (value) {
                          playlistName = value;
                        },
                      ),
                      Row(
                        children: [
                          Text(
                            "Where to add new songs in the future?",
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: Colors.white),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: playlistAdd,
                            icon: Icon(
                              FluentIcons.down,
                              color: Colors.white,
                              size: 24,
                            ),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                          labelStyle: Theme.of(
                            context,
                          ).textTheme.bodySmall!.copyWith(color: Colors.white),
                          labelText: 'Search',
                          suffixIcon: Icon(
                            FluentIcons.search,
                            color: Colors.white,
                            size: 20,
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
                                  return Center(
                                    child: Text(
                                      "Error loading songs",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.white),
                                    ),
                                  );
                                }
                                if ((snapshot.data ?? []).isEmpty) {
                                  return Center(
                                    child: Text(
                                      "No songs found",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(color: Colors.white),
                                    ),
                                  );
                                }
                                return CustomScrollView(
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.zero,
                                      sliver:
                                          ValueListenableBuilder<List<Song>>(
                                            valueListenable: selected,
                                            builder: (
                                              context,
                                              selectedSongs,
                                              child,
                                            ) {
                                              return ListComponent(
                                                items: snapshot.data ?? [],
                                                itemExtent: height * 0.125,
                                                isSelected: (entity) {
                                                  return selected.value
                                                      .contains(entity as Song);
                                                },
                                                onTap: (entity) {
                                                  if (selected.value.contains(
                                                    entity as Song,
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
                                                onLongPress: (entity) {},
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
