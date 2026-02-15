import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tiling/list_component.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/add_or_export_screen.dart';
import 'package:provider/provider.dart';

class AlbumScreen extends EntityScreen {
  static Route<void> route({required Album album}) {
    return PageRouteBuilder(
      settings: const RouteSettings(name: '/album', arguments: Album),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlbumScreen(entity: album as BaseEntity);
      },
    );
  }

  const AlbumScreen({super.key, required super.entity});

  @override
  Future<void> loadEntityData() async {
    var album = entity as Album;
    album.songs.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
  }

  @override
  Widget buildBody(BuildContext context, double width, double height) {
    var album = entity as Album;
    var boldSize = height * 0.025;
    var normalSize = height * 0.02;

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
                  var audioProvider = Provider.of<AudioProvider>(
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(height: height * 0.02),
              Hero(
                tag: album.name,
                child: Container(
                  height: width * 0.6,
                  width: width * 0.6,
                  padding: EdgeInsets.only(bottom: height * 0.01),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.height * 0.015,
                    ),
                    child: ImageWidget(entity: album),
                  ),
                ),
              ),
              SizedBox(height: height * 0.02),
              Text(
                album.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: boldSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.005),
              Text(
                album.songs.first.artist.target?.name ?? 'Unknown Artist',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: normalSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.005),
              Text(
                "${album.songs.length} Songs | ${Duration(seconds: album.durationInSeconds).pretty()}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: normalSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: height * 0.02),
            ],
          ),
        ),
        Expanded(
          child: GlassContainer(
            margin: EdgeInsets.symmetric(horizontal: width * 0.05),
            padding: EdgeInsets.only(
              right: width * 0.01,
              top: height * 0.01,
              bottom: height * 0.01,
            ),
            color: Colors.black.withValues(alpha: 0.4),
            borderGradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.60),
                Colors.indigoAccent.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.height * 0.015,
            ),
            blur: 45.0,
            borderWidth: 1.5,
            elevation: 3.0,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            isFrostedGlass: true,
            frostedOpacity: 0.15,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(vertical: height * 0.01),
                  sliver: ListComponent(
                    items: album.songs,
                    itemExtent: height * 0.1,
                    isSelected: (entity) {
                      return false;
                    },
                    onTap: (entity) async {
                      debugPrint("Tapped on ${entity.name}");
                      var audioProvider = Provider.of<AudioProvider>(
                        context,
                        listen: false,
                      );
                      audioProvider.setQueue(album.songs);
                      await audioProvider.setCurrentSong((entity as Song));
                      await audioProvider.play();
                    },
                    onLongPress: (entity) {
                      debugPrint("Long pressed on ${entity.name}");
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: height * 0.02),
      ],
    );
  }
}
