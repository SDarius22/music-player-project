import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/selection_provider.dart';
import 'package:music_player_frontend/core/ui/screens/multiple_entities_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/platforms/android/ui/components/widgets/android_search_header.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/album_screen.dart';
import 'package:provider/provider.dart';

class Albums extends MultipleEntitiesScreen<AlbumProvider> {
  static Route<dynamic> route({required AlbumProvider provider}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/albums'),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Albums(provider: provider);
      },
    );
  }

  const Albums({super.key, required super.provider});

  @override
  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.only(bottom: height * 0.01);
  }

  @override
  Widget buildLeftAction(BaseEntity entity, BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      icon: Icon(FluentIcons.play, color: Colors.white, size: height * 0.025),
      onPressed: () async {
        debugPrint("Playing album ${entity.name}");
        if (entity is! Album) {
          debugPrint("Entity is not an Album");
          return;
        }
        Album album = entity;
        album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
        var audioProvider = Provider.of<AudioProvider>(context, listen: false);
        audioProvider.setQueue(album.songs);
        await audioProvider.setCurrentSong(album.songs.first);
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
      onSelected: (String value) async {
        switch (value) {
          case 'add':
            Album album = entity as Album;
            album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
            var abstractAppStateProvider =
                Provider.of<AbstractAppStateProvider>(context, listen: false);
            abstractAppStateProvider.navigatorKey.currentState!.push(
              AddOrExportScreen.route(songs: album.songs),
            );
            break;
          case 'playNext':
            Album album = entity as Album;
            album.songs.sort((a, b) => b.trackNumber.compareTo(a.trackNumber));
            var audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            audioProvider.addNextToQueue(album.songs);
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
      AlbumScreen.route(album: entity as Album),
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
      child: AndroidSearchHeader(title: 'Albums', provider: provider),
    );
  }
}
