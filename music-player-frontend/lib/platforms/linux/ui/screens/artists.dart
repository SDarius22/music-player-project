import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/artist_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/screens/multiple_entities_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/widgets/linux_search_header.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/artist_screen.dart';
import 'package:provider/provider.dart';

class Artists extends MultipleEntitiesScreen<ArtistProvider> {
  static Route<dynamic> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return Artists(provider: context.read<ArtistProvider>());
      },
    );
  }

  const Artists({super.key, required super.provider});

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      icon: Icon(FluentIcons.play, color: Colors.white, size: height * 0.025),
      onPressed: () async {
        debugPrint("Playing artist ${entity.name}");
        if (entity is! Artist) {
          debugPrint("Entity is not an Artist");
          return;
        }
        Artist artist = entity;
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        await audioProvider.setQueueAndPlay(artist.songs, artist.songs.first);
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
        switch (value) {
          case 'add':
            Artist artist = entity as Artist;
            var abstractAppStateProvider =
                Provider.of<AbstractAppStateProvider>(context, listen: false);
            abstractAppStateProvider.navigatorKey.currentState!.push(
              AddOrExportScreen.route(songs: artist.songs),
            );
            break;
          case 'playNext':
            Artist artist = entity as Artist;
            var audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            audioProvider.addNextToQueue(artist.songs);
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
    AsyncSnapshot snapshot,
    BuildContext context,
  ) async {
    var abstractAppStateProvider = Provider.of<AbstractAppStateProvider>(
      context,
      listen: false,
    );
    abstractAppStateProvider.navigatorKey.currentState!.push(
      ArtistScreen.route(artist: entity as Artist),
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
      child: LinuxSearchHeader(title: 'Artists', provider: provider),
    );
  }
}
