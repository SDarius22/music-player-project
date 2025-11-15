import 'dart:typed_data';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

abstract class AbstractCreateOrImportScreen extends StatefulWidget {
  final String playlistName;
  final List<String> playlistPaths;
  final bool import;

  const AbstractCreateOrImportScreen({
    super.key,
    this.playlistName = "",
    this.playlistPaths = const [],
    this.import = false,
  });
}

abstract class AbstractCreateOrImportScreenState<
  T extends AbstractCreateOrImportScreen
>
    extends State<T> {
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
      coverArt.value ?? Constants.logoBytes,
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

  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.zero;
  }

  Widget buildBody(BuildContext context);
}
