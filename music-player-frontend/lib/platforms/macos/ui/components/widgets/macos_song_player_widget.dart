import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/ui/components/scaler.dart';
import 'package:music_player_frontend/core/ui/components/theme.dart';
import 'package:music_player_frontend/core/ui/components/widgets/song_player_widget.dart';
import 'package:music_player_frontend/local_libs/audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:music_player_frontend/local_libs/glass_kit/glass_container.dart';
import 'package:music_player_frontend/local_libs/miniplayer/miniplayer.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/tabs/details_tab.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/tabs/lyrics_tab.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/platforms/macos/ui/components/widgets/macos_volume_widget.dart';
import 'package:provider/provider.dart';

class MacosSongPlayerWidget extends SongPlayerWidget {
  const MacosSongPlayerWidget({super.key});

  @override
  State<SongPlayerWidget> createState() => MacosSongPlayerWidgetState();
}

class MacosSongPlayerWidgetState extends SongPlayerWidgetState {
  late AbstractAppStateProvider appStateProvider;
  late AudioProvider audioProvider;

  @override
  void initState() {
    super.initState();
    appStateProvider = context.read<AbstractAppStateProvider>();
    audioProvider = context.read<AudioProvider>();
  }

  @override
  double getMinHeight(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.1;
  }

  @override
  double getMaxHeight(BuildContext context) {
    return MediaQuery.of(context).size.height - appWindow.titleBarHeight;
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

    double normalized = (1.0 - (percentage / 0.25).clamp(0.0, 1.0));
    double progressBarOpacity = normalized;

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      blur: 45.0,
      elevation: 3.0,
      borderRadius: getBorderRadius(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.center,
            margin: EdgeInsets.only(left: imageLeftMargin),
            padding: const EdgeInsets.all(1),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: getBorderRadius(context),
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
              width: width * 0.2,
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
                      context.read<Scaler>(),
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
                      context.read<Scaler>(),
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
              width: width * 0.3,
              height: height * 0.15,
              child: const IgnorePointer(
                ignoring: true,
                child: LyricsTab(oneLine: true),
              ),
            ),
          ),

          const Spacer(),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.25,
              height: height * 0.15,
              child: _buildPlayerButtons(audioProvider),
            ),
          ),

          Opacity(
            opacity: progressBarOpacity,
            child: SizedBox(
              width: width * 0.05,
              height: height * 0.15,
              child: IconButton(
                onPressed:
                    () => Provider.of<AbstractAppStateProvider>(
                      context,
                      listen: false,
                    ).miniPlayerController.animateToHeight(
                      state: PanelState.max,
                    ),
                icon: Icon(
                  FluentIcons.maximize,
                  color: Colors.white,
                  size: height * 0.02,
                ),
              ),
            ),
          ),
        ],
      ),
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

    final maxRightMargin = width * 0.45;
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
        int currentSongIndex = audioProvider.currentIndexInNonShuffled;
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

    return GlassContainer(
      color: Colors.black.withValues(alpha: 0.4),
      borderColor: Colors.transparent,
      blur: 45.0,
      borderRadius: getBorderRadius(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Lyrics
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: Container(
                      width: width * 0.3,
                      height: width * 0.3,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      child: const LyricsTab(),
                    ),
                  ),

                const Spacer(),

                // Album Art
                Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(maxWidth: width * 0.325),
                  margin: EdgeInsets.only(right: imageRightMargin),
                  // width: width * 0.325,
                  child: DetailsTab(
                    opacity: detailsOpacity,
                    miniPlayerController: appStateProvider.miniPlayerController,
                  ),
                ),

                const Spacer(),
                // Queue
                if (showSidePanels)
                  Opacity(
                    opacity: sidePanelsOpacity,
                    child: Container(
                      width: width * 0.3,
                      height: width * 0.3,
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.01,
                        vertical: height * 0.01,
                      ),
                      child: QueueTab(
                        itemScrollController: itemScrollController,
                      ),
                    ),
                  ),
              ],
            ),
          ),

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
                                  buffered: Duration(
                                    seconds:
                                        audioProvider
                                            .bufferedPositionNotifier
                                            .value,
                                  ),
                                  total:
                                      snapshot.hasData
                                          ? snapshot.data as Duration
                                          : Duration.zero,

                                  progressBarColor:
                                      appStateProvider.colors.first,
                                  baseBarColor: appStateProvider.colors.last
                                      .withValues(alpha: 0.25),
                                  bufferedBarColor: appStateProvider.colors.last
                                      .withValues(alpha: 0.5),
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
                  MacosVolumeWidget(),

                  const Spacer(),

                  SizedBox(
                    width: width * 0.5,
                    child: _buildPlayerButtons(audioProvider),
                  ),

                  const Spacer(),

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
        ],
      ),
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
              await audioProvider.pause();
            } else {
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

  Widget _buildPlayerButtons(AudioProvider audioProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildShuffleButton(context),
        buildPreviousButton(context),
        buildPlayPauseButton(context),
        buildNextButton(context),
        buildRepeatButton(context),
      ],
    );
  }
}
