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
import 'package:fluenticons/fluenticons.dart';
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
  void onDropdownAction(
    BaseEntity entity,
    int dropdownIndex,
    BuildContext context,
  ) {
    final album = entity as Album;
    switch (dropdownIndex) {
      case 0:
        Provider.of<AbstractAppStateProvider>(context, listen: false)
            .innerNavigatorKey
            .currentState!
            .push(AddOrExportScreen.route(songs: album.getSongs()));
      case 1:
        Provider.of<AudioProvider>(
          context,
          listen: false,
        ).addNextToQueue(album.getSongs());
      case 2:
        final sp = Provider.of<SelectionProvider>(context, listen: false);
        if (sp.selectedEntities.contains(entity)) {
          sp.deselectEntity(entity);
        } else {
          sp.selectEntity(entity);
        }
    }
  }

  @override
  Future<void> onEntityTap(
    BaseEntity entity,
    List<dynamic> items,
    BuildContext context,
  ) async {
    Provider.of<AbstractAppStateProvider>(context, listen: false)
        .innerNavigatorKey
        .currentState!
        .push(AlbumScreen.route(album: entity as Album));
  }
}
