import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/local_libs/text_scroll/text_scroll.dart';
import 'package:music_player_frontend/platforms/android/ui/components/android_scaler.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/album_screen.dart';
import 'package:music_player_frontend/platforms/android/ui/screens/artist_screen.dart';
import 'package:provider/provider.dart';

class DetailsTab extends AbstractDetailsTab {
  final MiniPlayerController miniPlayerController;

  const DetailsTab({
    super.key,
    required this.miniPlayerController,
    required super.opacity,
  });

  @override
  Widget buildDetailsContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return Consumer<AudioProvider>(
      builder: (_, audioProvider, _) {
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.black,
              borderRadius: BorderRadius.circular(
                MediaQuery.of(context).size.height * 0.015,
              ),
              image: DecorationImage(
                fit: BoxFit.fill,
                image: MemoryImage(audioProvider.currentSong.coverArt),
              ),
            ),
            child: Stack(
              children: [
                Container(
                  alignment: Alignment.bottomCenter,
                  padding: EdgeInsets.only(bottom: height * 0.01),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.height * 0.015,
                    ),
                    gradient: LinearGradient(
                      begin: FractionalOffset.center,
                      end: FractionalOffset.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.75 * opacity),
                        Colors.black.withValues(alpha: 1.0 * opacity),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Opacity(
                    opacity: opacity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextScroll(
                          audioProvider.currentSong.name,
                          mode: TextScrollMode.bouncing,
                          velocity: const Velocity(
                            pixelsPerSecond: Offset(20, 0),
                          ),
                          style:
                              MusicPlayerTheme.getTheme(
                                context,
                                context.read<Scaler>(),
                              ).textTheme.displaySmall,
                          pauseOnBounce: const Duration(seconds: 5),
                          delayBefore: const Duration(seconds: 0),
                          pauseBetween: const Duration(seconds: 5),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: width * 0.01),
                            Expanded(
                              // width: width * 0.13,
                              // alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  miniPlayerController.animateToHeight(
                                    state: PanelState.min,
                                  );

                                  var artist =
                                      audioProvider.currentSong.artist.target;
                                  if (artist != null) {
                                    Navigator.push(
                                      context,
                                      ArtistScreen.route(artist: artist),
                                    );
                                  }
                                },
                                icon: Icon(
                                  FluentIcons.open,
                                  color: Colors.white,
                                  size: AndroidScaler().scale(context, 20),
                                ),
                                iconAlignment: IconAlignment.end,
                                label: TextScroll(
                                  audioProvider.currentSong.artist.target
                                      .toString(),
                                  mode: TextScrollMode.bouncing,
                                  velocity: const Velocity(
                                    pixelsPerSecond: Offset(25, 0),
                                  ),
                                  style:
                                      MusicPlayerTheme.getTheme(
                                        context,
                                        context.read<Scaler>(),
                                      ).textTheme.titleLarge,
                                  pauseOnBounce: const Duration(seconds: 5),
                                  delayBefore: const Duration(seconds: 0),
                                  pauseBetween: const Duration(seconds: 5),
                                ),
                              ),
                            ),
                            Icon(
                              FluentIcons.divider,
                              color: Colors.white,
                              size: AndroidScaler().scale(context, 16),
                            ),
                            Expanded(
                              // width: width * 0.13,
                              child: TextButton.icon(
                                onPressed: () async {
                                  miniPlayerController.animateToHeight(
                                    state: PanelState.min,
                                  );
                                  var album =
                                      audioProvider.currentSong.album.target;
                                  if (album != null) {
                                    Navigator.push(
                                      context,
                                      AlbumScreen.route(album: album),
                                    );
                                  }
                                },
                                icon: Icon(
                                  FluentIcons.open,
                                  color: Colors.white,
                                  size: AndroidScaler().scale(context, 20),
                                ),
                                label: TextScroll(
                                  audioProvider.currentSong.album.target
                                      .toString(),
                                  mode: TextScrollMode.bouncing,
                                  velocity: const Velocity(
                                    pixelsPerSecond: Offset(20, 0),
                                  ),
                                  style:
                                      MusicPlayerTheme.getTheme(
                                        context,
                                        context.read<Scaler>(),
                                      ).textTheme.titleLarge,
                                  pauseOnBounce: const Duration(seconds: 5),
                                  delayBefore: const Duration(seconds: 0),
                                  pauseBetween: const Duration(seconds: 5),
                                ),
                              ),
                            ),
                            SizedBox(width: width * 0.01),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: ClipPath(
                    clipper: _TriangleClipper(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.topRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.75 * opacity),
                            Colors.black.withValues(alpha: 1.0 * opacity),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 3.0, right: 3.0),
                      alignment: Alignment.topRight,
                      child: ValueListenableBuilder(
                        valueListenable: audioProvider.likedNotifier,
                        builder: (context, liked, child) {
                          return IconButton(
                            onPressed: () {
                              audioProvider.likeCurrentSong();
                            },
                            icon: Icon(
                              liked ? FluentIcons.liked : FluentIcons.unliked,
                              color: liked ? Colors.red : Colors.white,
                              size: AndroidScaler().scale(context, 24),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0); // Top Left (start of the hypotenuse)
    path.lineTo(size.width, 0); // Top Right
    path.lineTo(size.width, size.height); // Bottom Right
    path.close(); // Connects back to 0,0
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
