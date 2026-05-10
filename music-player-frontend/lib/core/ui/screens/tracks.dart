import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/multiple_entities_screen.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/route_builder.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/core/ui/screens/album_screen.dart';
import 'package:music_player_frontend/core/ui/screens/track_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class Tracks extends MultipleEntitiesScreen<SongProvider> {
  static Route<dynamic> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          Tracks(provider: context.read<SongProvider>()),
      settings: const RouteSettings(name: "/tracks"),
    );
  }

  const Tracks({super.key, required super.provider});

  @override
  String get screenTitle => 'Tracks';

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return IconButton(
      tooltip: "Go to Album",
      onPressed: () {
        final song = entity as Song;
        Navigator.push(
          context,
          AlbumScreen.route(album: song.album.target as Album),
        );
      },
      padding: const EdgeInsets.all(0),
      icon: const Icon(FluentIcons.album, color: Colors.white, size: 28),
    );
  }

  @override
  Widget buildMainAction(BaseEntity entity, BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (_, audioProvider, _) {
        final song = entity as Song;
        return ValueListenableBuilder(
          valueListenable: audioProvider.playingNotifier,
          builder: (context, isPlaying, child) {
            return Icon(
              audioProvider.currentSong == song && isPlaying == true
                  ? FluentIcons.pause
                  : FluentIcons.play,
              color: Colors.white,
            );
          },
        );
      },
    );
  }

  @override
  List<Widget Function(BaseEntity, BuildContext)> get extraActions => [
    (entity, context) => const Text("Add to..."),
    (entity, context) => const Text("Play Next"),
    (entity, context) => const Text("Select"),
    (entity, context) => const Text("Track Details"),
  ];

  @override
  void onDropdownAction(
    BaseEntity entity,
    int dropdownIndex,
    BuildContext context,
  ) {
    final song = entity as Song;
    switch (dropdownIndex) {
      case 0:
        Provider.of<AbstractAppStateProvider>(context, listen: false)
            .innerNavigatorKey
            .currentState
            ?.push(AddOrExportScreen.route(songs: [song]));
      case 1:
        Provider.of<AudioProvider>(context, listen: false)
            .addNextToQueue([song]);
      case 2:
        final sp = Provider.of<SelectionProvider>(context, listen: false);
        if (sp.selectedEntities.contains(entity)) {
          sp.deselectEntity(entity);
        } else {
          sp.selectEntity(entity);
        }
      case 3:
        Provider.of<AbstractAppStateProvider>(context, listen: false)
            .innerNavigatorKey
            .currentState
            ?.push(TrackScreen.route(song: song));
    }
  }

  @override
  Future<void> onEntityTap(
    BaseEntity entity,
    List<dynamic> items,
    BuildContext context,
  ) async {
    final song = entity as Song;
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    try {
      if (audioProvider.currentSong != song) {
        await audioProvider.setQueueAndPlay(
          items.whereType<Song>().toList(),
          song,
        );
      } else if (audioProvider.playingNotifier.value == true) {
        await audioProvider.pause();
      } else {
        await audioProvider.play();
      }
    } catch (e) {
      debugPrint(e.toString());
      await audioProvider.setQueueAndPlay(
        items.whereType<Song>().toList(),
        song,
      );
    }
  }
}
