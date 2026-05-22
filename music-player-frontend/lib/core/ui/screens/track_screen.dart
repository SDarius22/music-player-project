import 'package:duration/duration.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/ui/screens/abstract/entity_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class TrackScreen extends EntityScreen<SongProvider> {
  static Route<void> route({required Song song}) {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => TrackScreen(
        entity: song,
        provider: context.read<SongProvider>(),
        liked: song.likedByUser,
      ),
      settings: RouteSettings(name: "/track/${song.id}"),
    );
  }

  TrackScreen({
    super.key,
    required super.entity,
    required super.provider,
    this.liked = false,
  });

  final bool liked;
  late final ValueNotifier<bool> likeNotifier = ValueNotifier(liked);

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, BaseEntity entity) {
    final song = entity as Song;
    final height = MediaQuery.of(context).size.height;
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
              tooltip: "Add",
              padding: EdgeInsets.all(height * 0.005),
              onPressed: () {
                debugPrint("Add ${song.name}");
              },
              icon: Icon(FluentIcons.add, color: Colors.white, size: 24),
            ),
            IconButton(
              tooltip: "Play",
              padding: EdgeInsets.all(height * 0.005),
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
            ValueListenableBuilder<bool>(
              valueListenable: likeNotifier,
              builder: (context, liked, child) {
                return IconButton(
                  tooltip: "Like",
                  padding: EdgeInsets.all(height * 0.005),
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
  Widget buildContentSection(
    BuildContext context,
    BaseEntity entity,
    BoxConstraints constraints,
  ) {
    final song = entity as Song;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    var margin = EdgeInsets.symmetric(
      vertical: height * 0.01,
      horizontal: width * 0.02,
    );
    var borderRadius = BorderRadius.circular(height * 0.015);

    return GlassContainer(
      margin: margin,
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderRadius: borderRadius,
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
  }
}
