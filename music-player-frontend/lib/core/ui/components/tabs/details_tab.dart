import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/triangle_clipper.dart';
import 'package:music_player_frontend/core/ui/components/widgets/image_widget.dart';
import 'package:music_player_frontend/core/ui/screens/album_screen.dart';
import 'package:music_player_frontend/core/ui/screens/artist_screen.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/local_libs/text_scroll/custom_text_scroll.dart';
import 'package:provider/provider.dart';

class DetailsTab extends StatelessWidget {
  final double opacity;
  final Song currentSong;
  final MiniPlayerController miniPlayerController;

  const DetailsTab({
    super.key,
    required this.currentSong,
    required this.miniPlayerController,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    return Consumer<AudioProvider>(
      builder: (_, audioProvider, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.015),
          child: ImageWidget(
            key: const ValueKey<int>(2),
            entity: currentSong,
            otherStackChildren: [
              Opacity(
                opacity: opacity,
                child: Align(
                  alignment: Alignment.topRight,
                  child: ClipPath(
                    clipper: TriangleClipper(),
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
                            onPressed:
                                opacity < 0.7
                                    ? null
                                    : () {
                                      audioProvider.likeCurrentSong();
                                    },
                            icon: Icon(
                              liked ? FluentIcons.liked : FluentIcons.unliked,
                              color: liked ? Colors.red : Colors.white,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
            child: Container(
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(bottom: height * 0.01),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: Colors.black,
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
                    CustomTextScroll(
                      text: audioProvider.currentSong.name,
                      style:
                          MusicPlayerTheme.getTheme().textTheme.headlineMedium!,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: width * 0.01),
                        Expanded(
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
                              size: 20,
                            ),
                            iconAlignment: IconAlignment.end,
                            label: CustomTextScroll(
                              text:
                                  audioProvider.currentSong.artist.target
                                      .toString(),
                              style:
                                  MusicPlayerTheme.getTheme()
                                      .textTheme
                                      .titleMedium!,
                            ),
                          ),
                        ),
                        Icon(
                          FluentIcons.divider,
                          color: Colors.white,
                          size: 16,
                        ),
                        Expanded(
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
                              size: 20,
                            ),
                            label: CustomTextScroll(
                              text:
                                  audioProvider.currentSong.album.target
                                      .toString(),
                              style:
                                  MusicPlayerTheme.getTheme()
                                      .textTheme
                                      .titleMedium!,
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
          ),
        );
      },
    );
  }
}
