import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_player_frontend/core/constants.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/grid_tile.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/multiple_entities_screen.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/core/ui/screens/create_or_import_screen.dart';
import 'package:music_player_frontend/core/ui/screens/playlist_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class Playlists extends MultipleEntitiesScreen<PlaylistProvider> {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          Playlists(provider: context.read<PlaylistProvider>()),
      settings: const RouteSettings(name: "/playlists"),
    );
  }

  final Uint8List _createPlaylistImageBytes = Constants.createPlaylistBytes;

  Playlists({super.key, required super.provider});

  @override
  String get screenTitle => 'Playlists';

  @override
  Widget Function(BuildContext context)? get buildExtraTile => (context) {
    Playlist emptyPlaylist = Playlist();
    emptyPlaylist.name = "Create New Playlist";
    emptyPlaylist.indestructible = true;
    emptyPlaylist.imageBytes = _createPlaylistImageBytes;
    return CustomGridTile(
      onTap: () {
        var appState = Provider.of<AbstractAppStateProvider>(
          context,
          listen: false,
        );
        appState.innerNavigatorKey.currentState?.push(
          CreateOrImportScreen.route(),
        );
      },
      onLongPress: () {},
      entity: emptyPlaylist,
      isSelected: false,
      mainAction: const Icon(FluentIcons.add, color: Colors.white, size: 28),
    );
  };

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.play, color: Colors.white, size: 24),
      onPressed: () async {
        if (entity is! Playlist) return;
        Playlist playlist = entity;
        final songs = playlist.songsList;
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        await audioProvider.setQueueAndPlay(songs, songs.first);
      },
    );
  }

  @override
  Widget buildMainAction(BaseEntity entity, BuildContext context) {
    return const Icon(FluentIcons.open, color: Colors.white, size: 28);
  }

  @override
  Widget buildRightAction(BaseEntity entity, BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(FluentIcons.moreVertical, color: Colors.white, size: 28),
      onSelected: (String value) {},
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
    List<dynamic> items,
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
}
