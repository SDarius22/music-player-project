import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/multiple_entities_screen.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/core/ui/screens/album_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class Albums extends MultipleEntitiesScreen<AlbumProvider> {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          Albums(provider: context.read<AlbumProvider>()),
      settings: const RouteSettings(name: "/albums"),
    );
  }

  const Albums({super.key, required super.provider});

  @override
  String get screenTitle => 'Albums';

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.play, color: Colors.white, size: 24),
      onPressed: () async {
        if (entity is! Album) return;
        Album album = entity;
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        await audioProvider.setQueueAndPlay(
          album.getSongs(),
          album.getSongs().first,
        );
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
      onSelected: (String value) async {
        switch (value) {
          case 'add':
            Album album = entity as Album;
            var abstractAppStateProvider =
                Provider.of<AbstractAppStateProvider>(context, listen: false);
            abstractAppStateProvider.innerNavigatorKey.currentState!.push(
              AddOrExportScreen.route(songs: album.getSongs()),
            );
            break;
          case 'playNext':
            Album album = entity as Album;
            var audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            audioProvider.addNextToQueue(album.getSongs());
            break;
          case 'select':
            var selectionProvider = Provider.of<SelectionProvider>(
              context,
              listen: false,
            );
            var selected = selectionProvider.selectedEntities;
            if (selected.contains(entity)) {
              selectionProvider.deselectEntity(entity);
            } else {
              selectionProvider.selectEntity(entity);
            }
            break;
        }
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
    List<dynamic> items,
    BuildContext context,
  ) async {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    abstractAppStateProvider.innerNavigatorKey.currentState!.push(
      AlbumScreen.route(album: entity as Album),
    );
  }
}
