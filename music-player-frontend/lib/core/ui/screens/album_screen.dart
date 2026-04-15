import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/albums_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/core/ui/screens/add_or_export_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class AlbumScreen extends EntityScreen {
  static Route<void> route({required Album album}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => AlbumScreen(entity: album),
      settings: RouteSettings(name: "/album/${album.getHash()}"),
    );
  }

  const AlbumScreen({super.key, required super.entity});

  @override
  Future<BaseEntity> loadEntityData(BuildContext context) async {
    final album = entity as Album;
    try {
      var fetchedAlbum = await context.read<AlbumProvider>().fetchAlbumDetails(
        album.getHash(),
      );
      fetchedAlbum!.songs.sort((a, b) {
        final discComparison = a.discNumber.compareTo(b.discNumber);
        if (discComparison != 0) return discComparison;

        final trackComparison = a.trackNumber.compareTo(b.trackNumber);
        if (trackComparison != 0) return trackComparison;

        return a.name.compareTo(b.name);
      });
      return fetchedAlbum;
    } catch (e) {
      debugPrint("Error loading album details: $e");
      return album;
    }
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final album = entity as Album;
    var height = MediaQuery.of(context).size.height;
    return AppBar(
      leading: IconButton(
        onPressed: () {
          debugPrint("Back");
          Navigator.pop(context);
        },
        icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
      ),
      title: Text(entity.getName()),
      actionsPadding: EdgeInsets.symmetric(horizontal: height * 0.005),
      actions: [
        IconButton(
          tooltip: "Add",
          padding: EdgeInsets.all(height * 0.005),
          onPressed: () {
            debugPrint("Add ${album.name}");
            var abstractAppStateProvider =
                Provider.of<AbstractAppStateProvider>(context, listen: false);
            abstractAppStateProvider.innerNavigatorKey.currentState?.push(
              AddOrExportScreen.route(songs: album.getSongs()),
            );
          },
          icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
        ),
        IconButton(
          tooltip: "Play",
          padding: EdgeInsets.all(height * 0.005),
          onPressed: () async {
            debugPrint("Play ${album.name}");
            var audioProvider = Provider.of<AudioProvider>(
              context,
              listen: false,
            );
            await audioProvider.setQueueAndPlay(
              album.getSongs(),
              album.getSongs().first,
            );
          },
          icon: Icon(FluentIcons.play, color: Colors.white, size: 24),
        ),
        IconButton(
          tooltip: "Shuffle",
          onPressed: () async {},
          padding: EdgeInsets.all(height * 0.005),
          icon: Icon(FluentIcons.shuffleOn, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  @override
  Widget buildBody(BuildContext context, BaseEntity entity) {
    final album = entity as Album;
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          final imageSize = constraints.maxWidth * 0.45;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.05,
                  vertical: height * 0.02,
                ),
                child: Column(
                  children: [
                    Hero(
                      tag: album.getHash(),
                      child: Container(
                        height: imageSize,
                        width: imageSize,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageWidget(entity: album),
                        ),
                      ),
                    ),
                    Text(
                      album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.getArtistName(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${album.getSongs().length} Songs | ${Duration(seconds: album.getDurationInSeconds()).pretty()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GlassContainer(
                  margin: EdgeInsets.only(
                    left: width * 0.05,
                    right: width * 0.05,
                    bottom: height * 0.025,
                  ),
                  color: Colors.black.withValues(alpha: 0.4),
                  borderColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  blur: 45.0,
                  borderWidth: 0.0,
                  elevation: 3.0,
                  shadowColor: Colors.black.withValues(alpha: 0.20),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          vertical: height * 0.01,
                          horizontal: width * 0.01,
                        ),
                        sliver: ListComponent(
                          items: album.getSongs(),
                          itemExtent: height * 0.1,
                          isSelected: (entity) => false,
                          onTap: (entity) async {
                            var audioProvider = Provider.of<AudioProvider>(
                              context,
                              listen: false,
                            );
                            await audioProvider.setQueueAndPlay(
                              album.getSongs(),
                              entity as Song,
                            );
                          },
                          onLongPress: (entity) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: album.getHash(),
                      child: Container(
                        height: height * 0.5,
                        width: height * 0.5,
                        padding: EdgeInsets.only(bottom: height * 0.01),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.height * 0.015,
                          ),
                          child: ImageWidget(entity: album),
                        ),
                      ),
                    ),
                    Text(
                      album.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: height * 0.005),
                    Text(
                      album.getArtistName(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: height * 0.005),
                    Text(
                      "${album.getSongs().length} Songs | ${Duration(seconds: album.getDurationInSeconds()).pretty()}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GlassContainer(
                margin: EdgeInsets.only(
                  top: height * 0.025,
                  bottom: height * 0.025,
                  right: width * 0.05,
                ),
                color: Colors.black.withValues(alpha: 0.4),
                borderColor: Colors.transparent,
                borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.height * 0.015,
                ),
                blur: 45.0,
                borderWidth: 0.0,
                elevation: 3.0,
                shadowColor: Colors.black.withValues(alpha: 0.20),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        vertical: height * 0.01,
                        horizontal: width * 0.01,
                      ),
                      sliver: ListComponent(
                        items: album.getSongs(),
                        itemExtent: height * 0.1,
                        isSelected: (entity) {
                          return false;
                        },
                        onTap: (entity) async {
                          debugPrint("Tapped on ${entity.getName()}");
                          var audioProvider = Provider.of<AudioProvider>(
                            context,
                            listen: false,
                          );
                          await audioProvider.setQueueAndPlay(
                            album.getSongs(),
                            entity as Song,
                          );
                        },
                        onLongPress: (entity) {
                          debugPrint("Long pressed on ${entity.getName()}");
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
