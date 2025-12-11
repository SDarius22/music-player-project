import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class AlbumScreen extends EntityScreen {
  static Route<void> route({required Album album}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlbumScreen(entity: album as BaseEntity);
      },
    );
  }

  const AlbumScreen({super.key, required super.entity});

  @override
  Widget buildBody(BuildContext context, double width, double height) {
    var album = entity as Album;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: height * 0.065,
          width: width,
          padding: EdgeInsets.symmetric(horizontal: width * 0.01),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  debugPrint("Back");
                  Navigator.pop(context);
                },
                icon: Icon(
                  FluentIcons.back,
                  size: height * 0.02,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: "Add",
                padding: EdgeInsets.all(height * 0.005),
                onPressed: () {
                  debugPrint("Add ${album.name}");
                  var abstractAppStateProvider =
                      Provider.of<AbstractAppStateProvider>(
                        context,
                        listen: false,
                      );
                  abstractAppStateProvider.navigatorKey.currentState?.push(
                    AddOrExportScreen.route(songs: album.songs),
                  );
                },
                icon: Icon(
                  FluentIcons.add,
                  color: Colors.white,
                  size: height * 0.025,
                ),
              ),
              IconButton(
                tooltip: "Play",
                padding: EdgeInsets.all(height * 0.005),
                onPressed: () async {
                  debugPrint("Play ${album.name}");
                  var audioProvider = Provider.of<AbstractAudioProvider>(
                    context,
                    listen: false,
                  );
                  audioProvider.setQueue(album.songs);
                  await audioProvider.setCurrentSong(album.songs.first);
                  audioProvider.play();
                },
                icon: Icon(
                  FluentIcons.play,
                  color: Colors.white,
                  size: height * 0.025,
                ),
              ),
              IconButton(
                tooltip: "Shuffle",
                onPressed: () async {},
                padding: EdgeInsets.all(height * 0.005),
                icon: Icon(
                  FluentIcons.shuffleOn,
                  color: Colors.white,
                  size: height * 0.025,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
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
                        tag: album.name,
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
                        style:
                            MusicPlayerTheme.getTheme(
                              context,
                              context.read<Scaler>(),
                            ).textTheme.headlineMedium,
                      ),
                      SizedBox(height: height * 0.005),
                      Text(
                        album.artist.target?.name ?? "Unknown Artist",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            MusicPlayerTheme.getTheme(
                              context,
                              context.read<Scaler>(),
                            ).textTheme.bodyMedium,
                      ),
                      SizedBox(height: height * 0.005),
                      Text(
                        "${album.songs.length} Songs | ${Duration(seconds: album.duration).pretty()}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style:
                            MusicPlayerTheme.getTheme(
                              context,
                              context.read<Scaler>(),
                            ).textTheme.bodyMedium,
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
                        sliver: LinuxListComponent(
                          items: album.songs,
                          itemExtent: height * 0.1,
                          isSelected: (entity) {
                            return false;
                          },
                          onTap: (entity) async {
                            debugPrint("Tapped on ${entity.name}");
                            var audioProvider =
                                Provider.of<AbstractAudioProvider>(
                                  context,
                                  listen: false,
                                );
                            audioProvider.setQueue(album.songs);
                            await audioProvider.setCurrentSong(
                              (entity as Song),
                            );
                          },
                          onLongPress: (entity) {
                            debugPrint("Long pressed on ${entity.name}");
                            // Show context menu or options
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
