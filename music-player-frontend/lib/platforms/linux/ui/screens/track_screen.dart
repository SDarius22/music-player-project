import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/playlist_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/linux_scaler.dart';
import 'package:provider/provider.dart';

class TrackScreen extends EntityScreen {
  static Route<void> route({required Song song}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return TrackScreen(entity: song as BaseEntity, liked: song.likedByUser);
      },
    );
  }

  TrackScreen({super.key, required super.entity, this.liked = false});

  final bool liked;
  late final ValueNotifier<bool> likeNotifier = ValueNotifier(liked);

  @override
  EdgeInsetsGeometry buildPadding(double width, double height) {
    return EdgeInsets.only(bottom: height * 0.01);
  }

  @override
  Widget buildBody(BuildContext context, double width, double height) {
    var song = entity as Song;
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
                onPressed: () {
                  debugPrint("Add ${song.name}");
                  // Navigator.pushNamed(context, '/add', arguments: [song]);
                },
                icon: Icon(
                  FluentIcons.add,
                  color: Colors.white,
                  size: height * 0.025,
                ),
              ),
              IconButton(
                onPressed: () async {
                  debugPrint("Play ${song.name}");
                  var audioProvider = Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  );
                  await audioProvider.setQueueAndPlay([song], song);
                },
                icon: Icon(
                  FluentIcons.play,
                  color: Colors.white,
                  size: height * 0.025,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: likeNotifier,
                builder: (context, liked, child) {
                  return IconButton(
                    onPressed: () {
                      likeNotifier.value = !likeNotifier.value;
                      song.likedByUser = likeNotifier.value;
                      var songProvider = Provider.of<SongProvider>(
                        context,
                        listen: false,
                      );
                      songProvider.updateSong(song);

                      var playlistProvider = Provider.of<PlaylistProvider>(
                        context,
                        listen: false,
                      );
                      playlistProvider.updateFavoritesPlaylist();
                    },
                    icon: Icon(
                      liked ? FluentIcons.liked : FluentIcons.unliked,
                      color: liked ? Colors.red : Colors.white,
                      size: LinuxScaler().scale(context, 24),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: song.path,
                        child: Container(
                          height: height * 0.5,
                          width: height * 0.5,
                          padding: EdgeInsets.only(bottom: height * 0.01),
                          //color: Colors.red,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.height * 0.015,
                            ),
                            child: ImageWidget(entity: song),
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.01),
                      Text(
                        song.name,
                        style: TextStyle(
                          fontSize: boldSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [],
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
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text(
                              "Track Details",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: boldSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Song Name:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              song.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Artist:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              song.artist.target?.name ?? "Unknown Artist",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Album:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              song.album.target?.name ?? "Unknown Album",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Duration:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              Duration(
                                seconds: song.durationInSeconds,
                              ).pretty(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Year:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              song.year > 0
                                  ? song.year.toString()
                                  : "Unknown year",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            SizedBox(height: height * 0.01),
                            Text(
                              "Extra Info:",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              "Track: ${song.trackNumber} / Disc: ${song.discNumber}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              "Play Count: ${song.playCount}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              "Last Played: ${song.lastPlayed != null ? song.lastPlayed!.toLocal().toString() : "Never"}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                            Text(
                              "Path: ${song.path}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: normalSize,
                              ),
                            ),
                          ]),
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
