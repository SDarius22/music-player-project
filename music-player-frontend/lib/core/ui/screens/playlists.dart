import 'package:flutter/material.dart';
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

  const Playlists({super.key, required super.provider});

  @override
  String get screenTitle => 'Playlists';

  @override
  Widget Function(BuildContext context)? get buildExtraTile => (context) {
    Playlist emptyPlaylist = Playlist('Create New Playlist');
    emptyPlaylist.indestructible = true;
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
      isExtraTile: true,
    );
  };

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.play, color: Colors.white, size: 24),
      onPressed: () async {
        if (entity is! Playlist) return;
        final songs = entity.getSongs();
        if (songs.isEmpty) return;
        await Provider.of<AudioProvider>(
          context,
          listen: false,
        ).setQueueAndPlay(songs, songs.first);
      },
    );
  }

  @override
  Widget buildMainAction(BaseEntity entity, BuildContext context) {
    return const Icon(FluentIcons.open, color: Colors.white, size: 28);
  }

  @override
  List<Widget Function(BaseEntity, BuildContext)> get extraActions => [
    (entity, context) => const Text("Add to Playlist"),
    (entity, context) => const Text("Play Next"),
    (entity, context) => const Text("Select"),
  ];

  @override
  Future<void> onEntityTap(
    BaseEntity entity,
    List<dynamic> items,
    BuildContext context,
  ) async {
    Provider.of<AbstractAppStateProvider>(context, listen: false)
        .innerNavigatorKey
        .currentState!
        .push(PlaylistScreen.route(playlist: entity as Playlist));
  }
}
