import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/platforms/linux/providers/audio_provider.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/album_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/artist_screen.dart';
import 'package:music_player_frontend/utils/constants.dart';
import 'package:music_player_frontend/utils/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/utils/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/utils/text_scroll/text_scroll.dart';
import 'package:provider/provider.dart';

class DetailsTab extends AbstractDetailsTab {
  final MiniPlayerController miniPlayerController;

  const DetailsTab(
    this.miniPlayerController, {
    super.key,
    required super.opacity,
  });

  @override
  Widget buildDetailsContent(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;

    var boldSize = height * 0.025;
    var normalSize = height * 0.02;
    var smallSize = height * 0.015;

    return Consumer<AudioProvider>(
      builder: (_, audioProvider, __) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.black,
            borderRadius: BorderRadius.circular(width * 0.0125),
            image: DecorationImage(
              fit: BoxFit.cover,
              image:
                  Image.memory(
                    audioProvider.audioService.currentSong?.image ?? logoImage,
                  ).image,
            ),
          ),
          child: Container(
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.only(bottom: height * 0.01),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.black,
              borderRadius: BorderRadius.circular(width * 0.0125),
              gradient: LinearGradient(
                begin: FractionalOffset.center,
                end: FractionalOffset.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.75 * opacity),
                  Colors.black.withValues(alpha: 1.0 * opacity),
                ],
                stops: const [0.0, 0.5, 1.0],
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
                    velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: boldSize,
                      fontWeight: FontWeight.bold,
                    ),
                    pauseOnBounce: const Duration(seconds: 2),
                    delayBefore: const Duration(seconds: 2),
                    pauseBetween: const Duration(seconds: 2),
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
                            size: smallSize,
                          ),
                          iconAlignment: IconAlignment.end,
                          label: TextScroll(
                            audioProvider.currentSong.artist.toString(),
                            mode: TextScrollMode.bouncing,
                            velocity: const Velocity(
                              pixelsPerSecond: Offset(20, 0),
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                            ),
                            pauseOnBounce: const Duration(seconds: 2),
                            delayBefore: const Duration(seconds: 2),
                            pauseBetween: const Duration(seconds: 2),
                          ),
                        ),
                      ),
                      Icon(
                        FluentIcons.divider,
                        color: Colors.white,
                        size: normalSize,
                      ),
                      Expanded(
                        // width: width * 0.13,
                        child: TextButton.icon(
                          onPressed: () async {
                            miniPlayerController.animateToHeight(
                              state: PanelState.min,
                            );
                            var album = audioProvider.currentSong.album.target;
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
                            size: smallSize,
                          ),
                          label: TextScroll(
                            audioProvider.currentSong.album.toString(),
                            mode: TextScrollMode.bouncing,
                            velocity: const Velocity(
                              pixelsPerSecond: Offset(20, 0),
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: normalSize,
                              fontWeight: FontWeight.normal,
                            ),
                            pauseOnBounce: const Duration(seconds: 2),
                            delayBefore: const Duration(seconds: 2),
                            pauseBetween: const Duration(seconds: 2),
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
        );
      },
    );
  }
}
