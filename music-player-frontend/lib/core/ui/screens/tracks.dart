import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/search_header.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/multiple_entities_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/core/ui/screens/album_screen.dart';
import 'package:music_player_frontend/core/ui/screens/track_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class Tracks extends MultipleEntitiesScreen<SongProvider> {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return Tracks(provider: context.read<SongProvider>());
      },
    );
  }

  const Tracks({super.key, required super.provider});

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    return IconButton(
      tooltip: "Go to Album",
      onPressed: () {
        Song song = entity as Song;
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
        Song song = entity as Song;
        return ValueListenableBuilder(
          valueListenable: audioProvider.playingNotifier,
          builder: (context, isPlaying, child) {
            return Icon(
              audioProvider.currentSong == song &&
                      audioProvider.playingNotifier.value == true
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
  Widget buildRightAction(BaseEntity entity, BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        FluentIcons.moreVertical,
        color: Colors.white,
        size: 28,
      ),
      onSelected: (String value) {
        switch (value) {
          case 'add':
            var appState = Provider.of<AbstractAppStateProvider>(
              context,
              listen: false,
            );
            appState.innerNavigatorKey.currentState?.push(
              AddOrExportScreen.route(songs: [entity as Song]),
            );
            break;
          case 'playNext':
            var audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            audioProvider.addNextToQueue([(entity as Song)]);
            break;
          case 'select':
            debugPrint("Select ${entity.name}");
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
          case 'details':
            debugPrint("Details ${entity.name}");
            var appState = Provider.of<AbstractAppStateProvider>(
              context,
              listen: false,
            );
            appState.innerNavigatorKey.currentState?.push(
              TrackScreen.route(song: entity as Song),
            );
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
          const PopupMenuItem<String>(
            value: 'details',
            child: Text("Track Details"),
          ),
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
    var song = entity as Song;
    var audioProvider = Provider.of<AudioProvider>(context, listen: false);
    try {
      if (audioProvider.currentSong != song) {
        List<Song> songs = snapshot.data as List<Song>;
        debugPrint("Playing new song: ${song.name}");
        await audioProvider.setQueueAndPlay(songs, song);
      } else {
        if (audioProvider.playingNotifier.value == true) {
          debugPrint("Pausing song");
          await audioProvider.pause();
        } else {
          debugPrint("Playing song");
          await audioProvider.play();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      List<Song> songs = snapshot.data as List<Song>;
      await audioProvider.setQueueAndPlay(songs, song);
    }
  }

  @override
  Widget buildHeader(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Container(
      height: height * 0.065,
      width: width,
      padding: EdgeInsets.symmetric(horizontal: width * 0.01),
      child: SearchHeader(title: 'Tracks', provider: provider),
    );
  }
}
