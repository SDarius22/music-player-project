import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/local_libs/text_scroll/text_scroll.dart';
import 'package:music_player_frontend/platforms/linux/ui/components/linux_scaler.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/album_screen.dart';
import 'package:music_player_frontend/platforms/linux/ui/screens/artist_screen.dart';
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
      builder: (_, audioProvider, __) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.black,
              borderRadius: BorderRadius.circular(
                MediaQuery.of(context).size.height * 0.015,
              ),
              image: DecorationImage(
                fit: BoxFit.cover,
                image: MemoryImage(audioProvider.currentSong.coverArt),
              ),
            ),
            child: Container(
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
                      velocity: const Velocity(pixelsPerSecond: Offset(20, 0)),
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
                              size: LinuxScaler().scale(context, 20),
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
                          size: LinuxScaler().scale(context, 16),
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
                              size: LinuxScaler().scale(context, 20),
                            ),
                            label: TextScroll(
                              audioProvider.currentSong.album.target.toString(),
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
          ),
        );
      },
    );
  }
}
