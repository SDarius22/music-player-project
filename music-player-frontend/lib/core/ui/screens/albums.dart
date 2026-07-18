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
import 'package:music_player_frontend/core/services/entity_song_order.dart';
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
        final audioProvider = context.read<AudioProvider>();
        final songs = await EntitySongOrder.load(entity, provider);
        if (songs.isEmpty) return;
        await audioProvider.setQueueAndPlay(songs, songs.first);
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
  ) async {
    final album = entity as Album;
    if (dropdownIndex == 2) {
      final selection = context.read<SelectionProvider>();
      selection.isSelected(entity)
          ? selection.deselectEntity(entity)
          : selection.selectEntity(entity);
      return;
    }
    final appState = context.read<AbstractAppStateProvider>();
    final audioProvider = context.read<AudioProvider>();
    final songs = await EntitySongOrder.load(album, provider);
    switch (dropdownIndex) {
      case 0:
        appState.innerNavigatorKey.currentState?.push(
          AddOrExportScreen.route(songs: songs),
        );
      case 1:
        audioProvider.addNextToQueue(songs);
      case 2:
        return;
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
