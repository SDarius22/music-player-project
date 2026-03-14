import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/core/ui/screens/multiple_entities_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/playlist_screen.dart';
import 'package:provider/provider.dart';

class Playlists extends MultipleEntitiesScreen<PlaylistProvider> {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return Playlists(provider: context.read<PlaylistProvider>());
      },
    );
  }

  final Uint8List _createPlaylistImageBytes = Constants.createPlaylistBytes;

  Playlists({super.key, required super.provider});

  @override
  Widget Function(BuildContext context)? get buildExtraTile => (context) {
    var height = MediaQuery.of(context).size.height;
    Playlist emptyPlaylist = Playlist();
    emptyPlaylist.name = "Create New Playlist";
    emptyPlaylist.indestructible = true;
    emptyPlaylist.imageBytes = _createPlaylistImageBytes;
    return CustomGridTile(
      onTap: () {
        debugPrint("Create new playlist tapped");
        var appState = Provider.of<AbstractAppStateProvider>(
          context,
          listen: false,
        );
        appState.innerNavigatorKey.currentState?.push(
          CreateOrImportScreen.route(),
        );
      },
      onLongPress: () {
        debugPrint("Create new playlist long pressed");
      },
      entity: emptyPlaylist,
      isSelected: false,
      mainAction: Icon(
        FluentIcons.add,
        color: Colors.white,
        size: height * 0.03,
      ),
    );
  };

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      icon: Icon(FluentIcons.play, color: Colors.white, size: height * 0.025),
      onPressed: () async {
        debugPrint("Playing album ${entity.name}");
        if (entity is! Playlist) {
          debugPrint("Entity is not a Playlist");
          return;
        }
        Playlist playlist = entity;
        final songs = playlist.songsList;
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        await audioProvider.setQueueAndPlay(songs, songs.first);
      },
    );
  }

  @override
  Widget buildMainAction(BaseEntity entity, BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return Icon(FluentIcons.open, color: Colors.white, size: height * 0.03);
  }

  @override
  Widget buildRightAction(BaseEntity entity, BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return PopupMenuButton<String>(
      icon: Icon(
        FluentIcons.moreVertical,
        color: Colors.white,
        size: height * 0.03,
      ),
      onSelected: (String value) {
        // switch (value) {
        //   case 'add':
        //     Playlist playlist =
        //         entity as Playlist;
        //     final orderMap = {
        //       for (
        //         int i = 0;
        //         i <
        //             playlist
        //                 .pathsInOrder
        //                 .length;
        //         i++
        //       )
        //         playlist.pathsInOrder[i]: i,
        //     };
        //     playlist.songs.sort((a, b) {
        //       return (orderMap[a.path] ??
        //               playlist
        //                   .pathsInOrder
        //                   .length)
        //           .compareTo(
        //             orderMap[b.path] ??
        //                 playlist
        //                     .pathsInOrder
        //                     .length,
        //           );
        //     });
        //     var abstractAppStateProvider =
        //         Provider.of<
        //           AbstractAppStateProvider
        //         >(context, listen: false);
        //     abstractAppStateProvider
        //         .navigatorKey
        //         .currentState!
        //         .push(
        //           AddOrExportScreen.route(
        //             songs: playlist.songs,
        //           ),
        //         );
        //     break;
        //   case 'playNext':
        //     Playlist playlist =
        //         entity as Playlist;
        //     var audioProvider =
        //         Provider.of<AudioProvider>(
        //           context,
        //           listen: false,
        //         );
        //     audioProvider
        //         .addMultipleNextToQueue(
        //           playlist.pathsInOrder,
        //         );
        //     break;
        //   case 'select':
        //     Playlist playlist =
        //         entity as Playlist;
        //     if (selected.value.contains(
        //       playlist,
        //     )) {
        //       selected
        //           .value = List<Playlist>.from(
        //         selected.value,
        //       )..remove(playlist);
        //     } else {
        //       selected
        //           .value = List<Playlist>.from(
        //         selected.value,
        //       )..add(playlist);
        //     }
        //     break;
        // }
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
          const PopupMenuItem<String>(value: 'select', child: Text("Select")),
        ];
      },
    );
  }

  @override
  Future<void> onEntityTap(
    BaseEntity entity,
    AsyncSnapshot snapshot,
    BuildContext context,
  ) async {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    abstractAppStateProvider.innerNavigatorKey.currentState!.push(
      PlaylistScreen.route(playlist: entity as Playlist),
    );
  }

  @override
  Widget buildHeader(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Container(
      height: height * 0.065,
      width: width,
      padding: EdgeInsets.symmetric(horizontal: width * 0.01),
      child: LinuxSearchHeader(title: 'Playlists', provider: provider),
    );
  }
}
