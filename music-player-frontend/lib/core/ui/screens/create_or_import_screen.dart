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
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/multivaluelistenablebuilder/mvlb.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';

import 'abstract/route_builder.dart';

class CreateOrImportScreen extends StatefulWidget {
  static Route<void> route({
    String playlistName = "",
    List<String> songFileHashes = const [],
    bool import = false,
  }) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => CreateOrImportScreen(
        playlistName: playlistName,
        songFileHashes: songFileHashes,
        import: import,
      ),
      settings: RouteSettings(name: import ? "/import" : "/create"),
    );
  }

  final String playlistName;
  final List<String> songFileHashes;
  final bool import;

  const CreateOrImportScreen({
    super.key,
    this.playlistName = "",
    this.songFileHashes = const [],
    this.import = false,
  });

  @override
  State<CreateOrImportScreen> createState() => _CreateOrImportScreenState();
}

class _CreateOrImportScreenState extends State<CreateOrImportScreen> {
  late ValueNotifier<List<Song>> selected;
  late String playlistName;
  late String search;
  late ValueNotifier<Uint8List?> coverArt;
  late FocusNode searchNode;
  late FocusNode nameNode;

  final List<Song> _songs = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    selected = ValueNotifier<List<Song>>([]);
    playlistName = widget.playlistName;
    search = "";
    coverArt = ValueNotifier<Uint8List?>(null);
    searchNode = FocusNode();
    nameNode = FocusNode();
    _scrollController = ScrollController()..addListener(_onScroll);

    initializeSelectedSongs();
    nameNode.requestFocus();
    _fetchPage(0, reset: true);
  }

  @override
  void dispose() {
    selected.dispose();
    coverArt.dispose();
    searchNode.dispose();
    nameNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_hasMore || _isLoading) return;
      _fetchPage(_currentPage + 1);
    }
  }

  Future<void> _fetchPage(int page, {bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final result = await songProvider.fetchPage(
        search,
        'Title',
        true,
        false,
        page,
        30,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _songs.clear();
        _songs.addAll(result.content.whereType<Song>());
        _currentPage = result.page;
        _hasMore = result.page < result.totalPages - 1;
      });
    } catch (e) {
      debugPrint('CreateOrImportScreen: fetchPage error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(padding: buildPadding(context), child: buildBody(context)),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
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
              style: Theme.of(context).textTheme.headlineMedium,
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
      ),
    );
  }

  void initializeSelectedSongs() {
    if (widget.songFileHashes.isEmpty) return;

    if (widget.import) {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      selected.value =
          widget.songFileHashes
              .map((path) => songProvider.fetchSongByFileHash(path))
              .whereType<Song>()
              .toList();
      if (selected.value.isNotEmpty) {
        coverArt.value = selected.value.first.getCoverArt();
      }
    } else {
      selected.value = List.from(widget.songFileHashes);
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
    playlistProvider.addPlaylist(playlistName, selected.value, coverArt.value);

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
      initialDirectory:
          UniversalPlatform.isWeb ? null : appStates.appSettings.mainSongPlace,
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
    return EdgeInsets.zero;
  }

  Widget buildBody(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: height * 0.5,
                  width: height * 0.5,
                  padding: EdgeInsets.only(bottom: height * 0.01),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.height * 0.015,
                    ),
                    child: MultiValueListenableBuilder(
                      valueListenables: [coverArt, selected],
                      builder: (context, values, child) {
                        var cover = values[0] as Uint8List?;
                        if (cover != null) {
                          var playlist = Playlist('');
                          playlist.imageBytes = cover;

                          return ImageWidget(
                            entity: playlist,
                            hoveredChild: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _pickCoverArt,
                                  icon: Icon(
                                    FluentIcons.camera,
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
                        return ImageWidget(
                          entity:
                              selectedSongs.isNotEmpty
                                  ? selectedSongs.first
                                  : Song(''),
                          hoveredChild: IconButton(
                            onPressed: _pickCoverArt,
                            icon: Icon(
                              FluentIcons.camera,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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
            color: Colors.black.withValues(alpha: 0.4),
            borderColor: Colors.transparent,
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
            blur: 45.0,
            borderWidth: 0.0,
            elevation: 3.0,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: height * 0.02,
                    left: width * 0.01,
                    right: width * 0.01,
                  ),
                  child: TextFormField(
                    focusNode: searchNode,
                    onChanged: (value) {
                      search = value;
                      _fetchPage(0, reset: true);
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
                ),
                Expanded(
                  child:
                      _songs.isEmpty && !_isLoading
                          ? Center(
                            child: Text(
                              "No songs found",
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(color: Colors.white),
                            ),
                          )
                          : CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.symmetric(
                                  vertical: height * 0.01,
                                  horizontal: width * 0.01,
                                ),
                                sliver: ValueListenableBuilder<List<Song>>(
                                  valueListenable: selected,
                                  builder: (context, selectedSongs, child) {
                                    return ListComponent(
                                      items: _songs,
                                      itemExtent: height * 0.1,
                                      isSelected:
                                          (entity) => selectedSongs.contains(
                                            entity as Song,
                                          ),
                                      onTap: (entity) {
                                        final song = entity as Song;
                                        if (selected.value.contains(song)) {
                                          selected.value = List.from(
                                            selected.value,
                                          )..remove(song);
                                        } else {
                                          selected.value = List.from(
                                            selected.value,
                                          )..add(song);
                                        }
                                      },
                                      onLongPress: (entity) {},
                                    );
                                  },
                                ),
                              ),
                              if (_isLoading)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
