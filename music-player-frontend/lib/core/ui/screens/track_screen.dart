import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class TrackScreen extends EntityScreen {
  static Route<void> route({required Song song}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) =>
          TrackScreen(entity: song, liked: song.likedByUser),
      settings: RouteSettings(name: "/track/${song.id}"),
    );
  }

  TrackScreen({super.key, required super.entity, this.liked = false});

  final bool liked;
  late final ValueNotifier<bool> likeNotifier = ValueNotifier(liked);

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final song = entity as Song;
    final width = MediaQuery.of(context).size.width;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        height: kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: width * 0.01),
        margin: EdgeInsets.symmetric(vertical: width * 0.005),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () {
                debugPrint("Back");
                Navigator.pop(context);
              },
              icon: Icon(FluentIcons.back, size: 20, color: Colors.white),
            ),
            Text(
              entity.getName(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const Spacer(),
            IconButton(
              onPressed: () {
                debugPrint("Add ${song.name}");
              },
              icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
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
              icon: Icon(FluentIcons.play, color: Colors.white, size: 24),
            ),
            ValueListenableBuilder(
              valueListenable: likeNotifier,
              builder: (context, liked, child) {
                return IconButton(
                  onPressed: () async {
                    likeNotifier.value = !likeNotifier.value;
                    song.likedByUser = likeNotifier.value;
                    var songProvider = Provider.of<SongProvider>(
                      context,
                      listen: false,
                    );
                    await songProvider.updateSong(song);
                  },
                  icon: Icon(
                    liked ? FluentIcons.liked : FluentIcons.unliked,
                    color: liked ? Colors.red : Colors.white,
                    size: 24,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildBody(BuildContext context, BaseEntity entity) {
    var song = entity as Song;
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final detailsPanel = GlassContainer(
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
                  horizontal: width * 0.03,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      "Track Details",
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Song Name:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      song.name,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Artist:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      song.artist.target?.name ?? "Unknown Artist",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Album:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      song.album.target?.name ?? "Unknown Album",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Duration:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      Duration(seconds: song.durationInSeconds).pretty(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Year:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      song.year > 0 ? song.year.toString() : "Unknown year",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: height * 0.01),
                    Text(
                      "Extra Info:",
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Track: ${song.trackNumber} / Disc: ${song.discNumber}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    Text(
                      "Play Count: ${song.playCount}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                    Text(
                      "Last Played: ${song.lastPlayed != null ? song.lastPlayed!.toLocal().toString() : "Never"}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );

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
                      tag: song.getHash(),
                      child: Container(
                        height: imageSize,
                        width: imageSize,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageWidget(entity: song),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: width * 0.05,
                    right: width * 0.05,
                    bottom: height * 0.025,
                  ),
                  child: detailsPanel,
                ),
              ),
            ],
          );
        }

        return Row(
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
                      tag: song.getHash(),
                      child: Container(
                        height: height * 0.5,
                        width: height * 0.5,
                        padding: EdgeInsets.only(bottom: height * 0.01),
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
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
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
              child: Padding(
                padding: EdgeInsets.only(
                  top: height * 0.025,
                  bottom: height * 0.025,
                  right: width * 0.05,
                ),
                child: detailsPanel,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Future<BaseEntity> loadEntityData(BuildContext context) {
    final entity = this.entity as Song;
    return Future.value(entity); // TODO
  }
}
