import 'dart:ui';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/local_libs/audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/platforms/android/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/platforms/android/ui/components/theme.dart';
import 'package:provider/provider.dart';

class AndroidSongPlayerWidget extends SongPlayerWidget {
  const AndroidSongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => LinuxSongPlayerWidgetState();
}

class LinuxSongPlayerWidgetState extends SongPlayerWidgetState {
  late AbstractAppStateProvider appStateProvider;
  late AbstractAudioProvider audioProvider;

  @override
  void initState() {
    super.initState();
    appStateProvider = context.read<AbstractAppStateProvider>();
    audioProvider = context.read<AbstractAudioProvider>();
  }

  @override
  double getMinHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.075;
  }

  @override
  double getMaxHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  @override
  double getMinWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  @override
  double getMaxWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  @override
  double getItemExtent(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.1;
  }

  @override
  BorderRadius getBorderRadius(BuildContext context) {
    return BorderRadius.circular(MediaQuery.of(context).size.height * 0.015);
  }

  @override
  Widget buildMinimizedPlayerContent(BuildContext context, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    double minLeftMargin = 0;
    double maxLeftMargin = width * 0.725;
    double imageLeftMargin =
        lerpDouble(minLeftMargin, maxLeftMargin, percentage) ?? 0.0;
    if (imageLeftMargin < 0) {
      imageLeftMargin = 0;
    }

    double minTopMargin = 0;
    double maxTopMargin = height * 0.02;
    double imageTopMargin =
        lerpDouble(minTopMargin, maxTopMargin, percentage / 0.25) ?? 0.0;
    if (imageTopMargin < 0) {
      imageTopMargin = 0;
    }

    double minRadius = height * 0.015;
    double maxRadius = height * 0.015;
    double borderRadius = lerpDouble(maxRadius, minRadius, percentage) ?? 0.0;

    double normalized = (1.0 - (percentage / 0.25).clamp(0.0, 1.0));
    double progressBarOpacity = normalized;

    return Row(
      children: [
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.only(
            left: imageLeftMargin,
            top: imageTopMargin,
            bottom: imageTopMargin,
          ),
          padding: const EdgeInsets.all(1.5),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(borderRadius),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: cachedCoverArt,
                  isAntiAlias: true,
                ),
              ),
            ),
          ),
        ),

        Opacity(
          opacity: progressBarOpacity,
          child: Container(
            height: height * 0.15,
            width: width * 0.3,
            margin: EdgeInsets.only(left: width * 0.01),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audioProvider.currentSong.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MusicPlayerTheme.getTheme(
                    context,
                  ).textTheme.headlineLarge?.copyWith(
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        offset: const Offset(1, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Text(
                  audioProvider.currentSong.artist.target?.name ??
                      'Unknown Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MusicPlayerTheme.getTheme(
                    context,
                  ).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        offset: const Offset(1, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        Opacity(
          opacity: progressBarOpacity,
          child: SizedBox(
            width: width * 0.35,
            height: height * 0.15,
            child: _buildPlayerButtons(audioProvider),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildMaximizedPlayerContent(BuildContext context, double percentage) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    double normalizedPercentage = ((percentage - 0.25) / 0.75).clamp(0.0, 1.0);

    double fadeStart = 0.5;
    double fadeEnd = 1.0;
    double normalized = ((percentage - fadeStart) / (fadeEnd - fadeStart))
        .clamp(0.0, 1.0);

    double progressBarHeight = lerpDouble(0.0, height * 0.05, normalized)!;
    double buttonsHeight = lerpDouble(0.0, height * 0.15, normalized)!;
    double progressBarOpacity = normalized;

    final showSidePanels = normalizedPercentage > 0.8;
    final sidePanelsOpacity = ((normalizedPercentage - 0.8) / 0.2).clamp(
      0.0,
      1.0,
    );

    const maxRightMargin = 0.0;
    final imageRightMargin =
        showSidePanels
            ? 0.0
            : lerpDouble(
              maxRightMargin,
              0.0,
              normalizedPercentage.clamp(0.0, 0.7) / 0.7,
            )!; // Only moves when panels are gone

    final detailsOpacity = ((percentage - 0.7) / 0.3).clamp(0.0, 1.0);

    if (sidePanelsOpacity > 0.99) {
      if (itemScrollController.hasClients) {
        debugPrint("Jumping to current song index in queue");
        int currentSongIndex =
            audioProvider.audioService.currentIndexInNonShuffled;
        if (currentSongIndex > 15) {
          itemScrollController.jumpTo(height * 0.1 * (currentSongIndex - 10));
        }
        itemScrollController.animateTo(
          height * 0.1 * currentSongIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.only(right: imageRightMargin),
          child: DetailsTab(
            opacity: detailsOpacity,
            miniPlayerController: appStateProvider.miniPlayerController,
          ),
        ),

        const Spacer(),

        // ProgressBar
        Opacity(
          opacity: progressBarOpacity,
          child: SizedBox(
            height: progressBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.03),
              child:
                  sidePanelsOpacity > 0.99
                      ? FutureBuilder(
                        future: audioProvider.getDuration(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: LinearProgressIndicator(
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                            );
                          }
                          return ValueListenableBuilder(
                            valueListenable: audioProvider.sliderNotifier,
                            builder: (context, value, child) {
                              return ProgressBar(
                                progress: Duration(milliseconds: value),
                                total:
                                    snapshot.hasData
                                        ? snapshot.data as Duration
                                        : Duration.zero,

                                progressBarColor: appStateProvider.colors.first,
                                baseBarColor: appStateProvider.colors.last
                                    .withValues(alpha: 0.4),
                                thumbColor: Colors.white,
                                barHeight: 4.0,
                                thumbRadius: 7.0,
                                timeLabelLocation: TimeLabelLocation.sides,
                                timeLabelTextStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: height * 0.02,
                                  fontWeight: FontWeight.normal,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      offset: const Offset(1, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                timeLabelPadding: 5.0,
                                onSeek: (duration) {
                                  audioProvider.seek(duration);
                                },
                              );
                            },
                          );
                        },
                      )
                      : const Center(
                        child: LinearProgressIndicator(
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
            ),
          ),
        ),

        // Player Controls - Previous, Play/Pause, Next
        Opacity(
          opacity: progressBarOpacity,
          child: SizedBox(
            width: width * 0.9,
            height: buttonsHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () async {
                    debugPrint("Liked");
                    audioProvider.likeCurrentSong();
                    likedNotifier.value = !likedNotifier.value;
                    String message =
                        audioProvider.currentSong.liked
                            ? "Added ${audioProvider.currentSong.name} to Favorites"
                            : "Removed ${audioProvider.currentSong.name} from Favorites";
                    BotToast.showText(
                      text: message,
                      duration: const Duration(seconds: 3),
                      contentColor: Colors.black,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: height * 0.02,
                      ),
                    );
                  },
                  icon: Icon(
                    audioProvider.currentSong.liked
                        ? FluentIcons.liked
                        : FluentIcons.unliked,
                    size: height * 0.025,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(1, 2),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width: width * 0.5,
                  child: _buildPlayerButtons(audioProvider),
                ),

                IconButton(
                  onPressed: () async {
                    Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    ).miniPlayerController.animateToHeight(
                      state: PanelState.min,
                    );
                  },
                  icon: Icon(
                    FluentIcons.minimize,
                    color: Colors.white,
                    size: height * 0.025,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(1, 2),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  @override
  Widget buildPlayPauseButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.playingNotifier,
      builder: (context, value, child) {
        return IconButton(
          onPressed: () async {
            if (audioProvider.playingNotifier.value) {
              Provider.of<AbstractAppStateProvider>(
                context,
                listen: false,
              ).gradientController.stop();
              await audioProvider.pause();
            } else {
              Provider.of<AbstractAppStateProvider>(
                context,
                listen: false,
              ).gradientController.start();
              await audioProvider.play();
            }
          },
          icon: Icon(
            value ? FluentIcons.pause : FluentIcons.play,
            color: Colors.white,
            size: height * 0.03,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildNextButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      onPressed: () async {
        debugPrint("next");
        return await audioProvider.skipToNext();
      },
      icon: Icon(
        FluentIcons.next,
        color: Colors.white,
        size: height * 0.03,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 2),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildPreviousButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return IconButton(
      onPressed: () => audioProvider.skipToPrevious(),
      icon: Icon(
        FluentIcons.previous,
        color: Colors.white,
        size: height * 0.03,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(1, 2),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }

  @override
  Widget buildShuffleButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.shuffleNotifier,
      builder: (context, shuffle, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setShuffle(!audioProvider.shuffleNotifier.value);
          },
          icon: Icon(
            shuffle == false ? FluentIcons.shuffleOff : FluentIcons.shuffleOn,
            size: height * 0.03,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildRepeatButton(BuildContext context, {bool expanded = false}) {
    var height = MediaQuery.of(context).size.height;
    return ValueListenableBuilder(
      valueListenable: audioProvider.repeatNotifier,
      builder: (context, value, child) {
        return IconButton(
          onPressed: () {
            audioProvider.setRepeat(!audioProvider.repeatNotifier.value);
          },
          icon: Icon(
            value == false ? FluentIcons.repeatOff : FluentIcons.repeatOn,
            size: height * 0.025,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(1, 2),
                blurRadius: 7,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerButtons(AbstractAudioProvider audioProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildPreviousButton(context),
        buildPlayPauseButton(context),
        buildNextButton(context),
      ],
    );
  }
}
