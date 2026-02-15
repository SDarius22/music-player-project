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
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_search_header.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/playlist_screen.dart';
import 'package:provider/provider.dart';

class Playlists extends MultipleEntitiesScreen<PlaylistProvider> {
  static Route<dynamic> route({required PlaylistProvider provider}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/playlists'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Playlists(provider: provider);
      },
    );
  }

  final Uint8List _createPlaylistImageBytes = Constants.createPlaylistBytes;

  Playlists({super.key, required super.provider});

  @override
  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.only(bottom: height * 0.01);
  }

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
        appState.navigatorKey.currentState?.push(CreateOrImportScreen.route());
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
        debugPrint("Playing playlist ${entity.name}");
        if (entity is! Playlist) {
          debugPrint("Entity is not a Playlist");
          return;
        }
        Playlist playlist = entity;
        final songs = playlist.songsList;
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        audioProvider.setQueue(songs);
        await audioProvider.setCurrentSong(songs.first);
        audioProvider.play();
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
        // Playlist menu actions can be implemented here
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
    abstractAppStateProvider.navigatorKey.currentState!.push(
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
      child: AndroidSearchHeader(title: 'Playlists', provider: provider),
    );
  }
}
